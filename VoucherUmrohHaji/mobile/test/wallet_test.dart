import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'package:mobile/features/buyer/wallet_screen.dart';
import 'package:mobile/models/models.dart';
import 'package:mobile/providers/data_providers.dart';

WalletData _wallet() => WalletData(
      balance: 150000,
      owned: [
        VoucherOwned(
            title: 'Voucher Gold 500K',
            value: 525000,
            orderId: 'ORD-ABC123',
            createdAt: DateTime(2026, 10, 27, 10, 0)),
      ],
      ledger: [
        Ledger(
            type: 'topup',
            title: 'Top-Up Voucher Gold 500K',
            amount: 525000,
            orderId: 'ORD-ABC123',
            createdAt: DateTime(2026, 10, 27, 10, 1)),
        Ledger(
            type: 'withdraw',
            title: 'Hold withdraw ke BCA',
            amount: -50000,
            orderId: 'WD-1',
            createdAt: DateTime(2026, 10, 27, 11, 0)),
      ],
    );

Color? _warnaTeks(WidgetTester tester, String teks) =>
    tester.widget<Text>(find.text(teks)).style?.color;

void main() {
  setUpAll(() => initializeDateFormatting('id_ID', null));

  testWidgets('Ledger: mutasi masuk hijau (+), keluar merah (-)',
      (tester) async {
    await tester.pumpWidget(ProviderScope(
      overrides: [
        walletProvider.overrideWith((ref) async => _wallet()),
        myOrdersProvider.overrideWith((ref) async => [Order(
              id: 'ORD-ABC123',
              voucherTitle: 'Voucher Gold 500K',
              amount: 500000,
              value: 525000,
              status: 'settlement',
              createdAt: DateTime(2026, 10, 27, 10, 0),
            )]),
      ],
      child: const MaterialApp(home: Scaffold(body: WalletScreen())),
    ));
    await tester.pumpAndSettle();

    // '+Rp 525.000' muncul 2x: inventory voucher dan mutasi (keduanya hijau).
    expect(find.text('+Rp 525.000'), findsNWidgets(2));
    // Nominal keluar tampil "Rp -50.000" (ekspresi rupiah pada angka negatif).
    expect(find.text('Rp -50.000'), findsOneWidget);
    expect(
        tester
            .widgetList<Text>(find.text('+Rp 525.000'))
            .every((t) => t.style?.color == Colors.green[700]),
        isTrue);
    expect(_warnaTeks(tester, 'Rp -50.000'), Colors.red[700]);

    // Ikon mutasi: masuk panah bawah hijau, keluar panah atas merah.
    final ikon = tester
        .widgetList<Icon>(find.byType(Icon))
        .where((i) => i.icon == Icons.arrow_circle_down)
        .toList();
    expect(ikon.single.color, Colors.green[700]);

    // Pesanan ikut tampil dengan status capitalize.
    expect(find.text('ORD-ABC123'), findsOneWidget);
    expect(find.text('Settlement'), findsOneWidget);
  });

  testWidgets('Inventory kosong menampilkan teks kosong', (tester) async {
    await tester.pumpWidget(ProviderScope(
      overrides: [
        walletProvider.overrideWith(
            (ref) async => WalletData(balance: 0, owned: [], ledger: [])),
        myOrdersProvider.overrideWith((ref) async => []),
      ],
      child: const MaterialApp(home: Scaffold(body: WalletScreen())),
    ));
    await tester.pumpAndSettle();

    expect(find.text('Belum ada voucher'), findsOneWidget);
    expect(find.text('Belum ada mutasi'), findsOneWidget);
    expect(find.text('Belum ada pesanan'), findsOneWidget);
  });
}
