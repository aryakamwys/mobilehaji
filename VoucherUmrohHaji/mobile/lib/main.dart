import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'core/api_client.dart';
import 'core/token_storage.dart';
import 'features/auth/login_screen.dart';
import 'features/buyer/buyer_shell.dart';
import 'features/admin/admin_shell.dart';
import 'providers/auth_provider.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: '.env');
  await initializeDateFormatting('id_ID', null);
  await TokenStorage.load();
  final container = ProviderContainer();
  ApiClient.onSessionExpired =
      () => container.read(authProvider.notifier).sesiHabis();
  runApp(UncontrolledProviderScope(
    container: container,
    child: const VoucherApp(),
  ));
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
      navigatorKey: navigatorKey,
      home: const _Gerbang(),
    );
  }
}

/// Belum login → LoginScreen; sudah → shell sesuai role.
class _Gerbang extends ConsumerWidget {
  const _Gerbang();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authProvider);
    final member = auth.value;
    if (member == null) return const LoginScreen();
    return member.isAdmin ? const AdminShell() : const BuyerShell();
  }
}
