import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'features/auth/login_screen.dart';
import 'features/buyer/buyer_shell.dart';
import 'providers/store_provider.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: '.env');
  await initializeDateFormatting('id_ID', null);
  runApp(const ProviderScope(child: VoucherApp()));
}

class VoucherApp extends StatelessWidget {
  const VoucherApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Voucher Umroh & Haji',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF127A6B)),
      ),
      home: const _Gerbang(),
    );
  }
}

/// Belum login → LoginScreen; sudah → BuyerShell.
class _Gerbang extends ConsumerWidget {
  const _Gerbang();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sudahLogin = ref.watch(storeProvider).currentId != null;
    return sudahLogin ? const BuyerShell() : const LoginScreen();
  }
}
