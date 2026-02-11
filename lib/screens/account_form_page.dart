import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import '../models/account.dart';
import '../services/totp.dart';

class AccountFormPage extends StatefulWidget {
  const AccountFormPage({super.key, this.existing});

  final Account? existing;

  @override
  State<AccountFormPage> createState() => _AccountFormPageState();
}

class _AccountFormPageState extends State<AccountFormPage> {
  late final TextEditingController _providerController;
  late final TextEditingController _accountController;
  late final TextEditingController _secretController;

  @override
  void initState() {
    super.initState();
    _providerController =
      TextEditingController(text: widget.existing?.provider ?? '');
    _accountController =
      TextEditingController(text: widget.existing?.accountName ?? '');
    _secretController =
        TextEditingController(text: widget.existing?.secret ?? '');
  }

  @override
  void dispose() {
    _providerController.dispose();
    _accountController.dispose();
    _secretController.dispose();
    super.dispose();
  }

  void _save() {
    final provider = _providerController.text.trim();
    final accountName = _accountController.text.trim();
    final secret = _secretController.text.trim();
    if (provider.isEmpty || secret.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Provider and secret required')),
      );
      return;
    }
    if (!isValidBase32(secret)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Invalid Base32 secret')),
      );
      return;
    }
    final account = Account(
      id: widget.existing?.id ?? const Uuid().v4(),
      provider: provider,
      accountName: accountName,
      secret: secret,
      digits: widget.existing?.digits ?? 6,
      period: widget.existing?.period ?? 30,
      avatar: widget.existing?.avatar,
    );
    Navigator.of(context).pop(account);
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.existing != null;
    return Scaffold(
      appBar: AppBar(
        title: Text(isEditing ? 'Edit account' : 'Add account'),
        actions: [
          TextButton(
            onPressed: _save,
            child: const Text('Save'),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            controller: _providerController,
            decoration: const InputDecoration(labelText: 'Provider'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _accountController,
            decoration: const InputDecoration(labelText: 'Account (optional)'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _secretController,
            decoration: const InputDecoration(labelText: 'Secret (Base32)'),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: _save,
            child: const Text('Save'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }
}
