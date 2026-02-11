import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:rotary_scrollbar/rotary_scrollbar.dart';
import 'package:wear_plus/wear_plus.dart';

import '../models/account.dart';
import '../services/account_store.dart';
import '../services/totp.dart';
import '../widgets/account_avatar.dart';
import 'manage_page.dart';
import 'web_ui_page.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key, required this.store});

  final AccountStore store;

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  Timer? _timer;
  late final ValueNotifier<int> _nowMs;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _nowMs = ValueNotifier(DateTime.now().millisecondsSinceEpoch);
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      _nowMs.value = DateTime.now().millisecondsSinceEpoch;
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _scrollController.dispose();
    _nowMs.dispose();
    super.dispose();
  }

  Future<void> _openMenu() async {
    final choice = await showModalBottomSheet<_MenuChoice>(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      builder: (context) {
        final size = MediaQuery.sizeOf(context);
        return SizedBox(
          height: size.height,
          child: ListView(
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
            children: [
              const Center(
                child: Text(
                  'Menu',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                ),
              ),
              const SizedBox(height: 12),
              ListTile(
                leading: const Icon(Icons.manage_accounts),
                title: const Text('Manage accounts'),
                onTap: () => Navigator.of(context).pop(_MenuChoice.manage),
              ),
              ListTile(
                leading: const Icon(Icons.wifi),
                title: const Text('Web UI'),
                onTap: () => Navigator.of(context).pop(_MenuChoice.webUi),
              ),
            ],
          ),
        );
      },
    );

    if (!mounted || choice == null) return;
    switch (choice) {
      case _MenuChoice.manage:
        if (mounted) {
          await Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => ManagePage(store: widget.store),
            ),
          );
        }
        break;
      case _MenuChoice.webUi:
        if (mounted) {
          await Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => WebUiPage(store: widget.store),
            ),
          );
        }
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.store,
      builder: (context, _) {
        final accounts = widget.store.accounts;
        final textTheme = Theme.of(context).textTheme;
        return Scaffold(
          body: WatchShape(
            child: Column(
              children: [
                Expanded(
                  child: accounts.isEmpty
                      ? const Center(
                          child: Text('No accounts yet'),
                        )
                      : RotaryScrollbar(
                          controller: _scrollController,
                          scrollMagnitude: 10,
                          // padding: 20,
                          child: ListView.builder(
                            controller: _scrollController,
                            padding: const EdgeInsets.only(
                              top: 50,
                              bottom: 10,
                              left: 6,
                              right: 6,
                            ),
                            itemCount: accounts.length,
                            prototypeItem: const _AccountListItemPrototype(),
                            itemBuilder: (context, index) {
                              return _AccountListItem(
                                account: accounts[index],
                                nowMs: _nowMs,
                                textTheme: textTheme,
                              );
                            },
                          ),
                        ),
                ),
                const SizedBox(height: 5),
                FilledButton.tonalIcon(
                  onPressed: () => _openMenu(),
                  icon: const Icon(Icons.menu),
                  label: const Text('Menu'),
                ),
                const SizedBox(height: 5),
              ],
            ),
            builder: (context, shape, child) {
              return child ?? const SizedBox.shrink();
            },
          ),
        );
      },
    );
  }

}

enum _MenuChoice {
  manage,
  webUi,
}

class _TotpDisplay {
  const _TotpDisplay({required this.code, required this.progress});

  final String code;
  final double progress;
}

class _AccountListItem extends StatelessWidget {
  const _AccountListItem({
    required this.account,
    required this.nowMs,
    required this.textTheme,
  });

  final Account account;
  final ValueListenable<int> nowMs;
  final TextTheme textTheme;

  _TotpDisplay _buildDisplay(int currentMs) {
    final seconds = currentMs ~/ 1000;
    final period = account.period;
    final secondsLeft = period - (seconds % period);
    return _TotpDisplay(
      code: generateTotp(
        account.secret,
        currentMs,
        digits: account.digits,
        period: period,
      ),
      progress: secondsLeft / period,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(
        left: 6,
        right: 6,
        top: 4,
        bottom: 4,
      ),
      child: ListTile(
        dense: true,
        visualDensity: VisualDensity.compact,
        // minVerticalPadding: 10,
        titleAlignment: ListTileTitleAlignment.center,
        leading: AccountAvatar(
          account: account,
          radius: 14,
        ),
        title: Text(
          account.provider,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: textTheme.titleMedium,
        ),
        subtitle: Text(
          account.accountNameOnly,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: textTheme.bodyMedium,
        ),
        trailing: ValueListenableBuilder<int>(
          valueListenable: nowMs,
          builder: (context, currentMs, _) {
            final display = _buildDisplay(currentMs);
            return SizedBox(
              width: 56,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      display.code,
                      style: textTheme.titleLarge,
                    ),
                  ),
                  const SizedBox(height: 4),
                  LinearProgressIndicator(
                    value: display.progress,
                    minHeight: 3,
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _AccountListItemPrototype extends StatelessWidget {
  const _AccountListItemPrototype();

  @override
  Widget build(BuildContext context) {
    return const Card(
      margin: EdgeInsets.symmetric(
        horizontal: 6,
        vertical: 4,
      ),
      child: ListTile(
        dense: false,
        visualDensity: VisualDensity.standard,
        // minVerticalPadding: 10,
        titleAlignment: ListTileTitleAlignment.center,
        leading: SizedBox(width: 28, height: 28),
        title: Text('Prototype'),
        trailing: SizedBox(
          width: 56,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text('123456'),
              SizedBox(height: 4),
              LinearProgressIndicator(minHeight: 3),
            ],
          ),
        ),
      ),
    );
  }
}
