import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/auth_provider.dart';

/// Panel admin — stub F1. Layar admin (voucher CRUD, komisi, approval,
/// anggota) diimplementasikan di F2.
class AdminShell extends ConsumerWidget {
  const AdminShell({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final member = ref.watch(authProvider).value;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Panel Admin'),
        centerTitle: true,
        actions: [
          PopupMenuButton<String>(
            onSelected: (v) {
              if (v == 'keluar') ref.read(authProvider.notifier).logout();
            },
            itemBuilder: (_) => [
              PopupMenuItem(
                  enabled: false,
                  child: Text('Masuk sebagai ${member?.name ?? '-'}')),
              const PopupMenuDivider(),
              const PopupMenuItem(
                  value: 'keluar',
                  child: ListTile(
                      leading: Icon(Icons.logout),
                      title: Text('Keluar'),
                      contentPadding: EdgeInsets.zero)),
            ],
          ),
        ],
      ),
      body: const Center(
        child: Text('Panel admin belum tersedia'),
      ),
    );
  }
}
