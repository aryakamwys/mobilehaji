import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:mobile/features/admin/members_screen.dart';
import 'package:mobile/features/admin/voucher_editor_sheet.dart';
import 'package:mobile/models/models.dart';
import 'package:mobile/providers/admin_providers.dart';

MembersPage _halaman(List<String> nama, {required int totalPages}) =>
    MembersPage(
      items: nama
          .map((n) => Member(
                id: n,
                name: n,
                email: '$n@haji.local',
                role: 'buyer',
                referralCode: 'VCH-$n',
                balance: 100000,
                downlines: 2,
              ))
          .toList(),
      totalPages: totalPages,
);

Future<void> _pumpEditor(WidgetTester tester) async {
  await tester.pumpWidget(const ProviderScope(
      child: MaterialApp(
          home: Scaffold(body: VoucherEditorSheet(voucher: null)))));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('Editor voucher: form kosong tidak submit, tampil validasi',
      (tester) async {
    await _pumpEditor(tester);

    await tester.tap(find.text('Simpan Voucher'));
    await tester.pump();

    expect(
        find.text('Isi nama paket dan angka lebih dari 0'), findsOneWidget);
  });

  testWidgets('Editor voucher: harga 0 ditolak validasi', (tester) async {
    await _pumpEditor(tester);

    await tester.enterText(find.byType(TextFormField).at(0), 'Voucher Gold');
    await tester.enterText(find.byType(TextFormField).at(1), '0');
    await tester.enterText(find.byType(TextFormField).at(2), '0');
    await tester.tap(find.text('Simpan Voucher'));
    await tester.pump();

    expect(
        find.text('Isi nama paket dan angka lebih dari 0'), findsOneWidget);
  });

  testWidgets('Daftar anggota: render halaman + navigasi prev/next',
      (tester) async {
    await tester.pumpWidget(ProviderScope(
      overrides: [
        adminMembersPageProvider(1)
            .overrideWith((ref) async => _halaman(['Andi', 'Budi'], totalPages: 2)),
        adminMembersPageProvider(2)
            .overrideWith((ref) async => _halaman(['Citra'], totalPages: 2)),
      ],
      child: const MaterialApp(home: Scaffold(body: MembersScreen())),
    ));
    await tester.pumpAndSettle();

    expect(find.text('Andi'), findsOneWidget);
    expect(find.text('Budi'), findsOneWidget);
    expect(find.text('Halaman 1/2'), findsOneWidget);

    await tester.tap(find.text('Berikutnya'));
    await tester.pumpAndSettle();

    expect(find.text('Citra'), findsOneWidget);
    expect(find.text('Halaman 2/2'), findsOneWidget);
    expect(find.text('Andi'), findsNothing);

    await tester.tap(find.text('Sebelumnya'));
    await tester.pumpAndSettle();

    expect(find.text('Halaman 1/2'), findsOneWidget);
  });
}
