import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mali_wallet/main.dart';

void main() {
  testWidgets('Mali Wallet starts successfully', (WidgetTester tester) async {
    await tester.pumpWidget(const MaliWalletApp());
    expect(find.byType(MaterialApp), findsOneWidget);
    expect(find.byType(Scaffold), findsOneWidget);
  });
}
