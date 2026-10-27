import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:mobile/core/widgets/balance_card.dart';

void main() {
  testWidgets('BalanceCard menampilkan saldo format Rupiah', (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(body: BalanceCard(title: 'Saldo aktif', amount: 150000)),
    ));

    expect(find.text('Saldo aktif'), findsOneWidget);
    expect(find.text('Rp 150.000'), findsOneWidget);
  });
}
