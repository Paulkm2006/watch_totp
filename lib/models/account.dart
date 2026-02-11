class Account {
  const Account({
    required this.id,
    required this.provider,
    required this.accountName,
    required this.secret,
    required this.digits,
    required this.period,
    this.avatar,
  });

  final String id;
  final String provider;
  final String accountName;
  final String secret;
  final int digits;
  final int period;
  final String? avatar;

  String get displayName {
    final trimmedProvider = provider.trim();
    final trimmedAccount = accountName.trim();
    if (trimmedProvider.isNotEmpty && trimmedAccount.isNotEmpty) {
      return '$trimmedProvider ($trimmedAccount)';
    }
    if (trimmedProvider.isNotEmpty) {
      return trimmedProvider;
    }
    if (trimmedAccount.isNotEmpty) {
      return trimmedAccount;
    }
    return 'Account';
  }

  String get accountNameOnly {

    final tmp = accountName.split(':');
    if (tmp.length > 1) {
      return tmp[1].trim();
    }
    return accountName.trim();
  }

  factory Account.fromJson(Map<String, dynamic> json) {
    final legacyName = (json['name'] as String?)?.trim() ?? '';
    final provider = (json['provider'] as String?)?.trim() ??
        (json['issuer'] as String?)?.trim() ??
        legacyName;
    final accountName = (json['account'] as String?)?.trim() ??
        (json['accountName'] as String?)?.trim() ??
        (json['username'] as String?)?.trim() ??
        '';
    return Account(
      id: json['id'] as String,
      provider: provider,
      accountName: accountName,
      secret: json['secret'] as String,
      digits: (json['digits'] as num?)?.toInt() ?? 6,
      period: (json['period'] as num?)?.toInt() ?? 30,
      avatar: json['avatar'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'provider': provider,
        'account': accountName,
        'name': displayName,
        'secret': secret,
        'digits': digits,
        'period': period,
        'avatar': avatar,
      };
}
