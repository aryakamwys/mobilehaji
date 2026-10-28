import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:mobile/features/auth/login_screen.dart';

void main() {
  testWidgets('Form login kosong tidak submit, tampil pesan validasi',
      (tester) async {
    await tester.pumpWidget(const ProviderScope(
        child: MaterialApp(home: LoginScreen())));

    await tester.tap(find.text('Masuk'));
    await tester.pump();

    expect(find.text('Isi email'), findsOneWidget);
    expect(find.text('Isi password'), findsOneWidget);
    // Tidak boleh pindah ke shell buyer.
    expect(find.text('Top-Up'), findsNothing);
  });

  testWidgets('Email terisi tanpa password tetap ditolak validasi',
      (tester) async {
    await tester.pumpWidget(const ProviderScope(
        child: MaterialApp(home: LoginScreen())));

    await tester.enterText(
        find.byType(TextFormField).first, 'budi@haji.local');
    await tester.tap(find.text('Masuk'));
    await tester.pump();

    expect(find.text('Isi password'), findsOneWidget);
    expect(find.text('Isi email'), findsNothing);
  });
}
