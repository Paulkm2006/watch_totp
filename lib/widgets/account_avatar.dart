import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../models/account.dart';

class AccountAvatar extends StatelessWidget {
  const AccountAvatar({super.key, required this.account, this.radius = 18});

  final Account account;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final avatar = account.avatar;
    if (avatar == null || avatar.isEmpty) {
      return _defaultAvatar(context);
    }

    final bytes = _tryDecodeAvatar(avatar);
    if (bytes == null) {
      return _defaultAvatar(context);
    }

    return CircleAvatar(
      radius: radius,
      backgroundImage: MemoryImage(bytes),
      backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
    );
  }

  Widget _defaultAvatar(BuildContext context) {
    return CircleAvatar(
      radius: radius,
      backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: Icon(
        Icons.person,
        size: radius,
        color: Theme.of(context).colorScheme.onSurfaceVariant,
      ),
    );
  }

  Uint8List? _tryDecodeAvatar(String raw) {
    try {
      final data = UriData.parse(raw);
      return data.contentAsBytes();
    } catch (_) {
      try {
        return base64Decode(raw);
      } catch (_) {
        return null;
      }
    }
  }
}
