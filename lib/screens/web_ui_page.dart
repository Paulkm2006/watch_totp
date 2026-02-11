import 'package:flutter/material.dart';
import 'package:rotary_scrollbar/rotary_scrollbar.dart';
import 'package:wear_plus/wear_plus.dart';

import '../services/account_store.dart';
import '../services/web_ui_server.dart';

class WebUiPage extends StatefulWidget {
  const WebUiPage({super.key, required this.store, this.showAppBar = true});

  final AccountStore store;
  final bool showAppBar;

  @override
  State<WebUiPage> createState() => _WebUiPageState();
}

class _WebUiPageState extends State<WebUiPage> {
  final WebUiServer _server = WebUiServer();
  final ScrollController _scrollController = ScrollController();
  List<String> _urls = const [];
  String? _error;

  @override
  void dispose() {
    _server.stop();
    _scrollController.dispose();
    super.dispose();
  }

  Widget _wrapForRound(BuildContext context, Widget child) {
    if (!widget.showAppBar) {
      return child;
    }
    return WatchShape(
      child: child,
      builder: (context, shape, child) {
        final size = MediaQuery.sizeOf(context);
        final inset =
            shape == WearShape.round ? size.shortestSide * 0.08 : 0.0;
        return Padding(
          padding: EdgeInsets.symmetric(vertical: inset),
          child: child ?? const SizedBox.shrink(),
        );
      },
    );
  }

  Future<void> _startServer() async {
    setState(() {
      _error = null;
    });
    try {
      final urls = await _server.start(widget.store);
      setState(() {
        _urls = urls;
      });
    } catch (error) {
      setState(() {
        _error = '$error';
      });
    }
  }

  Future<void> _stopServer() async {
    await _server.stop();
    setState(() {
      _urls = const [];
    });
  }

  @override
  Widget build(BuildContext context) {
    final isRunning = _server.isRunning;
    return Scaffold(
      appBar: widget.showAppBar
          ? AppBar(
              title: const Text('Web UI'),
            )
          : null,
      body: _wrapForRound(
        context,
        RotaryScrollbar(
          controller: _scrollController,
          scrollMagnitude: 10,
          child: ListView(
            controller: _scrollController,
            padding: const EdgeInsets.all(12),
            children: [
              Center(
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    OutlinedButton(
                      onPressed: !isRunning ? _startServer : null,
                      child: const Icon(
                        Icons.play_arrow,
                        color: Colors.greenAccent,
                      ),
                    ),
                    OutlinedButton(
                      onPressed: isRunning ? _stopServer : null,
                      child: const Icon(
                        Icons.stop,
                        color: Colors.redAccent,
                      ),
                    ),
                  ],
                ),
              ),
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(
                  _error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ],
              const SizedBox(height: 12),
              if (isRunning && _urls.isEmpty)
                const Text('Server is running. No LAN address found.'),
              if (_urls.isNotEmpty) ...[
                const Text('Open one of these URLs:'),
                const SizedBox(height: 8),
                ..._urls.map(
                  (url) => Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: SelectableText(
                      url,
                      textAlign: TextAlign.left,
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 16),
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: const Text(
                  'Keep the app open while using the web UI.',
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}
