import 'package:flutter/material.dart';
import 'package:wear_plus/wear_plus.dart';

import '../screens/main_screen.dart';
import '../services/account_store.dart';

class MainApp extends StatelessWidget {
  const MainApp({super.key, required this.store});

  final AccountStore store;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      builder: (context, child) {
        final media = MediaQuery.of(context);
        final textScale = media.textScaler.scale(1.0).clamp(0.8, 0.9);
        final mediaChild = MediaQuery(
          data: media.copyWith(textScaler: TextScaler.linear(textScale)),
          child: child ?? const SizedBox.shrink(),
        );
        return WatchShape(
          child: mediaChild,
          builder: (context, shape, child) {
            final content = child ?? const SizedBox.shrink();
            return shape == WearShape.round ? ClipOval(child: content) : content;
          },
        );
      },
      theme: ThemeData(
        brightness: Brightness.dark,
        colorSchemeSeed: Colors.green,
        useMaterial3: true,
        visualDensity: VisualDensity.compact,
        appBarTheme: const AppBarTheme(toolbarHeight: 44),
        listTileTheme: const ListTileThemeData(
          dense: true,
          contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          visualDensity: VisualDensity.compact,
        ),
      ),
      home: MainScreen(store: store),
    );
  }
}
