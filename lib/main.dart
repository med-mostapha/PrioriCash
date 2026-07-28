import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:prioricash/generated/l10n.dart';
import 'package:prioricash/presentation/screens/home_screen.dart';
import 'package:prioricash/presentation/theme/app_theme.dart';

void main() {
  runApp(const ProviderScope(child: SmartWalletApp()));
}

class SmartWalletApp extends StatelessWidget {
  const SmartWalletApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      onGenerateTitle: (context) => S.of(context).appTitle,
      theme: AppTheme.dark,
      debugShowCheckedModeBanner: false,
      localizationsDelegates: const [
        S.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: S.delegate.supportedLocales,
      home: const HomeScreen(),
    );
  }
}
