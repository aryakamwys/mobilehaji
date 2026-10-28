import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/auth_provider.dart';
import 'approvals_screen.dart';
import 'members_screen.dart';
import 'mlm_config_screen.dart';
import 'vouchers_screen.dart';

/// Kerangka admin: app bar + 4 tab (Voucher, Komisi, Approval, Anggota).
class AdminShell extends ConsumerStatefulWidget {
  const AdminShell({super.key});

  @override
  ConsumerState<AdminShell> createState() => _AdminShellState();
}

class _AdminShellState extends ConsumerState<AdminShell> {
  int _tab = 0;

  @override
  Widget build(BuildContext context) {
    final member = ref.watch(authProvider).value;
    final layar = [
      const VouchersScreen(),
      const MlmConfigScreen(),
      const ApprovalsScreen(),
      const MembersScreen(),
    ];
    return Scaffold(
      appBar: AppBar(
        title: const Text('Panel Admin'),
        centerTitle: true,
        actions: [
          PopupMenuButton<String>(
            onSelected: (v) {
              if (v == 'keluar') {
                ref.read(authProvider.notifier).logout();
              }
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
      body: IndexedStack(index: _tab, children: layar),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: (i) => setState(() => _tab = i),
        destinations: const [
          NavigationDestination(
              icon: Icon(Icons.card_giftcard_outlined),
              selectedIcon: Icon(Icons.card_giftcard),
              label: 'Voucher'),
          NavigationDestination(
              icon: Icon(Icons.hub_outlined),
              selectedIcon: Icon(Icons.hub),
              label: 'Komisi'),
          NavigationDestination(
              icon: Icon(Icons.verified_user_outlined),
              selectedIcon: Icon(Icons.verified_user),
              label: 'Approval'),
          NavigationDestination(
              icon: Icon(Icons.people_outline),
              selectedIcon: Icon(Icons.people),
              label: 'Anggota'),
        ],
      ),
    );
  }
}
