import 'package:flutter/material.dart';

import 'app/main_app.dart';
import 'services/account_store.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final store = AccountStore();
  await store.load();
  runApp(MainApp(store: store));
}
