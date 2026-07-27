import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:prioricash/generated/l10n.dart';
import 'package:prioricash/presentation/screens/debug_screen.dart';

void main() {
  runApp(const ProviderScope(child: SmartWalletApp()));
}

class SmartWalletApp extends StatelessWidget {
  const SmartWalletApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      onGenerateTitle: (context) => S.of(context).appTitle,
      localizationsDelegates: const [
        S.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: S.delegate.supportedLocales,
      // SW-12: the debug screen is the entire app for now. Replaced by the
      // real home screen in SW-16, once every acceptance criterion has
      // been proven on-device.
      home: const DebugScreen(),
    );
  }
}
