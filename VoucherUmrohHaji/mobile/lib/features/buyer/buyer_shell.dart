import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/auth_provider.dart';
import 'referral_screen.dart';
import 'shop_screen.dart';
import 'wallet_screen.dart';
import 'withdraw_screen.dart';

/// Kerangka buyer: app bar + 4 tab (Top-Up, Dompet, Referal, Withdraw).
class BuyerShell extends ConsumerStatefulWidget {
  const BuyerShell({super.key});

  @override
  ConsumerState<BuyerShell> createState() => _BuyerShellState();
}

class _BuyerShellState extends ConsumerState<BuyerShell> {
  int _tab = 0;

  @override
  Widget build(BuildContext context) {
    final member = ref.watch(authProvider).value;
    final layar = [
      const ShopScreen(),
      const WalletScreen(),
      const ReferralScreen(),
      const WithdrawScreen(),
    ];
    return Scaffold(
      appBar: AppBar(
        title: const Text('Voucher Umroh & Haji'),
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
                  enabled: false, child: Text('Masuk sebagai ${member?.name ?? '-'}')),
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
              icon: Icon(Icons.shopping_bag_outlined),
              selectedIcon: Icon(Icons.shopping_bag),
              label: 'Top-Up'),
          NavigationDestination(
              icon: Icon(Icons.account_balance_wallet_outlined),
              selectedIcon: Icon(Icons.account_balance_wallet),
              label: 'Dompet'),
          NavigationDestination(
              icon: Icon(Icons.group_outlined),
              selectedIcon: Icon(Icons.group),
              label: 'Referal'),
          NavigationDestination(
              icon: Icon(Icons.outbound_outlined),
              selectedIcon: Icon(Icons.outbound),
              label: 'Withdraw'),
        ],
      ),
    );
  }
}
