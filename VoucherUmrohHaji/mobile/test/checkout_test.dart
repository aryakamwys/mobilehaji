import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:mobile/core/token_storage.dart';
import 'package:mobile/features/buyer/checkout_sheet.dart';
import 'package:mobile/models/models.dart';

Member _member({String? parentId}) => Member(
      id: 'm1',
      name: 'Budi',
      email: 'budi@haji.local',
      role: 'buyer',
      referralCode: 'VCH-BUDI01',
      parentId: parentId,
    );

Voucher get _voucher => Voucher(
    id: 'v1', title: 'Voucher Gold 500K', price: 500000, value: 525000, isActive: true);

Future<void> _pump(WidgetTester tester) async {
  // authProvider.build() hanya memakai member bila token ada (guard sesi).
  TokenStorage.accessToken = 'token';
  TokenStorage.refreshToken = 'token';
  await tester.pumpWidget(ProviderScope(child: MaterialApp(
    home: Scaffold(
      body: CheckoutSheet(voucher: _voucher),
    ),
  )));
  await tester.pumpAndSettle();
}

void main() {
  tearDown(() {
    TokenStorage.accessToken = null;
    TokenStorage.refreshToken = null;
    TokenStorage.member = null;
  });

  testWidgets(
      'Field kode referral tampil saat parentId masih null (belum punya upline)',
      (tester) async {
    TokenStorage.member = _member(parentId: null);
    await _pump(tester);

    expect(find.text('Kode referral (opsional)'), findsOneWidget);
    expect(find.text('Buat Order'), findsOneWidget);
  });

  testWidgets('Field kode referral tersembunyi saat sudah punya upline',
      (tester) async {
    TokenStorage.member = _member(parentId: 'm2');
    await _pump(tester);

    expect(find.text('Kode referral (opsional)'), findsNothing);
  });

  testWidgets('Detail voucher tampil di checkout', (tester) async {
    TokenStorage.member = _member(parentId: 'm2');
    await _pump(tester);

    expect(find.text('Voucher Gold 500K'), findsOneWidget);
    expect(find.text('Rp 500.000'), findsOneWidget);
    expect(find.text('Rp 525.000'), findsOneWidget);
  });
}
