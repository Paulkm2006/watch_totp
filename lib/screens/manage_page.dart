import 'package:flutter/material.dart';
import 'package:rotary_scrollbar/rotary_scrollbar.dart';
import 'package:wear_plus/wear_plus.dart';

import '../models/account.dart';
import '../services/account_store.dart';
import '../widgets/account_avatar.dart';
import 'account_form_page.dart';

class ManagePage extends StatefulWidget {
  const ManagePage({super.key, required this.store, this.showAppBar = true});

  final AccountStore store;
  final bool showAppBar;

  @override
  State<ManagePage> createState() => _ManagePageState();
}

class _ManagePageState extends State<ManagePage> {
  final ScrollController _scrollController = ScrollController();

  @override
  void dispose() {
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

  Future<void> _reorderAccounts(int oldIndex, int newIndex) async {
    final accounts = widget.store.accounts.toList();
    if (newIndex > oldIndex) {
      newIndex -= 1;
    }
    final account = accounts.removeAt(oldIndex);
    accounts.insert(newIndex, account);
    await widget.store.replaceAll(accounts);
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.store,
      builder: (context, _) {
        final accounts = widget.store.accounts;
        final content = accounts.isEmpty
            ? const Center(child: Text('Add your first account'))
            : RotaryScrollbar(
                controller: _scrollController,
                scrollMagnitude: 10,
                child: ReorderableListView.builder(
                  scrollController: _scrollController,
                  buildDefaultDragHandles: false,
                  onReorder: (oldIndex, newIndex) async {
                    await _reorderAccounts(oldIndex, newIndex);
                  },
                  itemCount: accounts.length,
                  padding: const EdgeInsets.only(bottom: 30, left: 6, right: 6),
                  itemBuilder: (context, index) {
                    final account = accounts[index];
                    return Card(
                      key: ValueKey(account.id),
                      margin: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 4,
                      ),
                      child: ListTile(
                        leading: AccountAvatar(account: account, radius: 16),
                        title: Text(
                          account.provider,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        subtitle: Text(
                          account.accountName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            ReorderableDelayedDragStartListener(
                              index: index,
                              child: const Icon(Icons.drag_handle),
                            ),
                            PopupMenuButton<String>(
                              onSelected: (value) async {
                                if (value == 'edit') {
                                  final updated =
                                      await Navigator.of(context).push<Account>(
                                    MaterialPageRoute(
                                      builder: (_) =>
                                          AccountFormPage(existing: account),
                                    ),
                                  );
                                  if (updated != null) {
                                    await widget.store.update(updated);
                                  }
                                  return;
                                }
                                if (value == 'delete') {
                                  final ok = await showDialog<bool>(
                                    context: context,
                                    builder: (context) {
                                      return AlertDialog(
                                        title: const Text('Delete account?'),
                                        content: Text(account.displayName),
                                        actions: [
                                          TextButton(
                                            onPressed: () =>
                                                Navigator.of(context).pop(false),
                                            child: const Text('Cancel'),
                                          ),
                                          TextButton(
                                            onPressed: () =>
                                                Navigator.of(context).pop(true),
                                            child: const Text('Delete'),
                                          ),
                                        ],
                                      );
                                    },
                                  );
                                  if (ok == true) {
                                    await widget.store.remove(account.id);
                                  }
                                }
                              },
                              itemBuilder: (context) => const [
                                PopupMenuItem(
                                  value: 'edit',
                                  child: Text('Edit'),
                                ),
                                PopupMenuItem(
                                  value: 'delete',
                                  child: Text('Delete'),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              );
        return Scaffold(
          appBar: widget.showAppBar
              ? AppBar(
                  title: const Text('Accounts'),
                )
              : null,
          floatingActionButton: FloatingActionButton(
            mini: true,
            onPressed: () async {
              final created = await Navigator.of(context).push<Account>(
                MaterialPageRoute(
                  builder: (_) => const AccountFormPage(),
                ),
              );
              if (created != null) {
                await widget.store.add(created);
              }
            },
            child: const Icon(Icons.add),
          ),
          body: _wrapForRound(context, content),
        );
      },
    );
  }
}
