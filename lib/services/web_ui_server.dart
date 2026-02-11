import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:uuid/uuid.dart';

import '../models/account.dart';
import 'account_store.dart';
import 'totp.dart';

class WebUiServer {
  HttpServer? _server;
  AccountStore? _store;
  String? _webUiHtml;
  final int port;

  WebUiServer({this.port = 8787});

  bool get isRunning => _server != null;

  Future<List<String>> start(AccountStore store) async {
    if (kIsWeb) {
      throw StateError('Web UI is not supported on web builds.');
    }
    if (_server != null) {
      return _buildUrls();
    }
    _store = store;
    await _getWebUiHtml();
    final server = await HttpServer.bind(InternetAddress.anyIPv4, port);
    _server = server;
    server.autoCompress = true;
    server.listen(_handleRequest);
    return _buildUrls();
  }

  Future<void> stop() async {
    await _server?.close(force: true);
    _server = null;
  }

  Future<void> _handleRequest(HttpRequest request) async {
    final response = request.response;
    response.headers.set('Access-Control-Allow-Origin', '*');
    response.headers.set('Access-Control-Allow-Methods', 'GET,POST,PUT,DELETE');
    response.headers.set('Access-Control-Allow-Headers', 'Content-Type');
    if (request.method == 'OPTIONS') {
      response.statusCode = HttpStatus.noContent;
      await response.close();
      return;
    }

    final path = request.uri.path;
    if (request.method == 'GET' && path == '/') {
      response.headers.contentType = ContentType.html;
      try {
        response.write(await _getWebUiHtml());
      } catch (error) {
        response.statusCode = HttpStatus.internalServerError;
        response.write('Failed to load web UI: $error');
      }
      await response.close();
      return;
    }

    if (path.startsWith('/api/accounts')) {
      await _handleAccountsApi(request);
      return;
    }

    if (path == '/api/import/stratum') {
      await _handleStratumImport(request);
      return;
    }

    response.statusCode = HttpStatus.notFound;
    response.write('Not found');
    await response.close();
  }

  Future<void> _handleAccountsApi(HttpRequest request) async {
    final response = request.response;
    response.headers.contentType = ContentType.json;
    final store = _store;
    if (store == null) {
      response.statusCode = HttpStatus.serviceUnavailable;
      response.write(jsonEncode({'error': 'Store not ready'}));
      await response.close();
      return;
    }

    final segments = request.uri.pathSegments;
    final id = segments.length >= 3 ? segments[2] : null;
    final isReorder = segments.length >= 3 && segments[2] == 'reorder';

    if (request.method == 'GET') {
      response.write(jsonEncode(store.accounts.map((a) => a.toJson()).toList()));
      await response.close();
      return;
    }

    final body = await utf8.decoder.bind(request).join();
    final data = body.isEmpty ? <String, dynamic>{} : jsonDecode(body);

    if (request.method == 'POST' && isReorder) {
      final payload = data is Map<String, dynamic> ? data : null;
      final targetId = payload?['id'] as String?;
      final direction = payload?['direction'] as String?;
      final offset = direction == 'up'
          ? -1
          : direction == 'down'
              ? 1
              : 0;
      if (targetId == null || offset == 0) {
        response.statusCode = HttpStatus.badRequest;
        response.write(jsonEncode({'error': 'Invalid reorder payload'}));
        await response.close();
        return;
      }
      await store.moveById(targetId, offset);
      response.write(jsonEncode({'ok': true}));
      await response.close();
      return;
    }

    if (request.method == 'POST') {
      final created = _accountFromPayload(data as Map<String, dynamic>);
      if (created == null) {
        response.statusCode = HttpStatus.badRequest;
        response.write(jsonEncode({'error': 'Invalid payload'}));
        await response.close();
        return;
      }
      await store.add(created);
      response.write(jsonEncode(created.toJson()));
      await response.close();
      return;
    }

    if (request.method == 'PUT' && id != null) {
      Account? existing;
      for (final account in store.accounts) {
        if (account.id == id) {
          existing = account;
          break;
        }
      }
      final updated = _accountFromPayload(
        data as Map<String, dynamic>,
        idOverride: id,
        existing: existing,
      );
      if (updated == null) {
        response.statusCode = HttpStatus.badRequest;
        response.write(jsonEncode({'error': 'Invalid payload'}));
        await response.close();
        return;
      }
      await store.update(updated);
      response.write(jsonEncode(updated.toJson()));
      await response.close();
      return;
    }

    if (request.method == 'DELETE' && id != null) {
      await store.remove(id);
      response.write(jsonEncode({'ok': true}));
      await response.close();
      return;
    }

    response.statusCode = HttpStatus.methodNotAllowed;
    response.write(jsonEncode({'error': 'Unsupported method'}));
    await response.close();
  }

  Future<void> _handleStratumImport(HttpRequest request) async {
    final response = request.response;
    response.headers.contentType = ContentType.json;
    final store = _store;
    if (store == null) {
      response.statusCode = HttpStatus.serviceUnavailable;
      response.write(jsonEncode({'error': 'Store not ready'}));
      await response.close();
      return;
    }

    if (request.method != 'POST') {
      response.statusCode = HttpStatus.methodNotAllowed;
      response.write(jsonEncode({'error': 'Unsupported method'}));
      await response.close();
      return;
    }

    final body = await utf8.decoder.bind(request).join();
    final data = body.isEmpty ? null : jsonDecode(body);
    if (data is! Map<String, dynamic>) {
      response.statusCode = HttpStatus.badRequest;
      response.write(jsonEncode({'error': 'Invalid payload'}));
      await response.close();
      return;
    }

    final rawAccounts = data['accounts'];
    if (rawAccounts is! List) {
      response.statusCode = HttpStatus.badRequest;
      response.write(jsonEncode({'error': 'Invalid accounts payload'}));
      await response.close();
      return;
    }

    final replace = data['replace'] == true;
    final imported = <Account>[];
    final errors = <String>[];

    for (var i = 0; i < rawAccounts.length; i += 1) {
      final item = rawAccounts[i];
      if (item is! Map<String, dynamic>) {
        errors.add('Account ${i + 1}: invalid payload');
        continue;
      }
      final account = _accountFromPayload(item);
      if (account == null) {
        errors.add('Account ${i + 1}: invalid account');
        continue;
      }
      imported.add(account);
    }

    if (replace) {
      await store.replaceAll(imported);
    } else {
      for (final account in imported) {
        await store.add(account);
      }
    }

    response.write(
      jsonEncode(
        {
          'imported': imported.length,
          'skipped': errors.length,
          'errors': errors,
        },
      ),
    );
    await response.close();
  }

  Account? _accountFromPayload(
    Map<String, dynamic> data, {
    String? idOverride,
    Account? existing,
  }) {
    final provider = (data['provider'] as String?)?.trim() ?? '';
    final accountName = (data['account'] as String?)?.trim() ??
        (data['accountName'] as String?)?.trim() ??
        '';
    final legacyName = (data['name'] as String?)?.trim() ?? '';
    final resolvedProvider = provider.isNotEmpty ? provider : legacyName;
    final secret = (data['secret'] as String?)?.trim() ?? '';
    if (secret.isEmpty || !isValidBase32(secret)) {
      return null;
    }
    if (resolvedProvider.isEmpty && accountName.isEmpty) {
      return null;
    }
    final avatar = _avatarFromPayload(data, existing: existing);
    return Account(
      id: idOverride ?? (data['id'] as String? ?? const Uuid().v4()),
      provider: resolvedProvider,
      accountName: accountName,
      secret: secret,
      digits: (data['digits'] as num?)?.toInt() ?? 6,
      period: (data['period'] as num?)?.toInt() ?? 30,
      avatar: avatar,
    );
  }

  String? _avatarFromPayload(
    Map<String, dynamic> data, {
    Account? existing,
  }) {
    if (data.containsKey('avatar')) {
      final value = data['avatar'];
      if (value is String && value.isNotEmpty) {
        return value;
      }
      return null;
    }
    return existing?.avatar;
  }

  Future<List<String>> _buildUrls() async {
    final addresses = await _localIpv4Addresses();
    if (addresses.isEmpty) {
      return ['http://127.0.0.1:$port'];
    }
    return addresses.map((addr) => 'http://${addr.address}:$port').toList();
  }

  Future<List<InternetAddress>> _localIpv4Addresses() async {
    final interfaces = await NetworkInterface.list(
      type: InternetAddressType.IPv4,
      includeLinkLocal: false,
    );
    final results = <InternetAddress>[];
    for (final interface in interfaces) {
      for (final address in interface.addresses) {
        if (!address.isLoopback) {
          results.add(address);
        }
      }
    }
    return results;
  }

  Future<String> _getWebUiHtml() async {
    final cached = _webUiHtml;
    if (cached != null) {
      return cached;
    }
    final loaded = await rootBundle.loadString('assets/web_ui.html');
    _webUiHtml = loaded;
    return loaded;
  }
}
