import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:WaledNet/main.dart';
import 'package:WaledNet/theme_provider.dart';

void main() {
  testWidgets('VPN app smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(
      ChangeNotifierProvider(
        create: (context) => ThemeProvider(),
        child: const VpnApp(),
      ),
    );
  });
}
