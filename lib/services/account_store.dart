import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../models/account.dart';

class AccountStore extends ChangeNotifier {
  static const String _accountsKey = 'accounts';

  final List<Account> _accounts = [];
  final FlutterSecureStorage _storage = const FlutterSecureStorage();
  bool _loaded = false;

  List<Account> get accounts => List.unmodifiable(_accounts);

  Future<void> load() async {
    if (_loaded) return;
    final raw = await _storage.read(key: _accountsKey);
    if (raw != null && raw.isNotEmpty) {
      final decoded = jsonDecode(raw) as List<dynamic>;
      _accounts
        ..clear()
        ..addAll(
          decoded.map((item) => Account.fromJson(item as Map<String, dynamic>)),
        );
    }
    _loaded = true;
    notifyListeners();
  }

  Future<void> _persist() async {
    final encoded = jsonEncode(_accounts.map((a) => a.toJson()).toList());
    await _storage.write(key: _accountsKey, value: encoded);
    notifyListeners();
  }

  Future<void> add(Account account) async {
    _accounts.add(account);
    await _persist();
  }

  Future<void> update(Account account) async {
    final index = _accounts.indexWhere((a) => a.id == account.id);
    if (index == -1) return;
    _accounts[index] = account;
    await _persist();
  }

  Future<void> remove(String id) async {
    _accounts.removeWhere((a) => a.id == id);
    await _persist();
  }

  Future<void> replaceAll(List<Account> accounts) async {
    _accounts
      ..clear()
      ..addAll(accounts);
    await _persist();
  }

  Future<void> moveById(String id, int offset) async {
    if (offset == 0) return;
    final fromIndex = _accounts.indexWhere((a) => a.id == id);
    if (fromIndex == -1) return;
    final toIndex = (fromIndex + offset).clamp(0, _accounts.length - 1);
    if (fromIndex == toIndex) return;
    final item = _accounts.removeAt(fromIndex);
    _accounts.insert(toIndex, item);
    await _persist();
  }
}
