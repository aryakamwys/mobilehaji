import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/rupiah.dart';
import '../../core/string_ext.dart';
import '../../core/tanggal.dart';
import '../../core/widgets/balance_card.dart';
import '../../providers/store_provider.dart';

class WalletScreen extends ConsumerWidget {
  const WalletScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final store = ref.watch(storeProvider);
    final owned = store.userOwned;
    final ledger = store.userLedger;
    final orders = store.userOrders;
    return RefreshIndicator(
      onRefresh: () async => await Future.delayed(const Duration(milliseconds: 300)),
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          BalanceCard(title: 'Dompet Saya', amount: store.current.balance),
          _judul(context, 'Inventory Voucher (${owned.length})'),
          if (owned.isEmpty)
            const _Kosong(teks: 'Belum ada voucher')
          else
            ...owned.map((o) => ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(o.title,
                      style: const TextStyle(fontWeight: FontWeight.w700)),
                  subtitle: Text('${o.orderId} • ${tanggalPendek(o.createdAt)}'),
                  trailing: Text('+${o.value.rupiah}',
                      style: TextStyle(
                          color: Colors.green[700],
                          fontWeight: FontWeight.w700)),
                )),
          const Divider(height: 28),
          _judul(context, 'Mutasi Saldo'),
          if (ledger.isEmpty)
            const _Kosong(teks: 'Belum ada mutasi')
          else
            ...ledger.map((l) => ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(
                      l.amount >= 0
                          ? Icons.arrow_circle_down
                          : Icons.arrow_circle_up,
                      color: l.amount >= 0 ? Colors.green[700] : Colors.red[700]),
                  title: Text(l.title,
                      style: const TextStyle(
                          fontSize: 14, fontWeight: FontWeight.w700)),
                  subtitle: Text(tanggalPendek(l.createdAt)),
                  trailing: Text(
                      '${l.amount > 0 ? '+' : ''}${l.amount.rupiah}',
                      style: TextStyle(
                          fontSize: 14,
                          color:
                              l.amount >= 0 ? Colors.green[700] : Colors.red[700],
                          fontWeight: FontWeight.w700)),
                )),
          const Divider(height: 28),
          _judul(context, 'Pesanan'),
          if (orders.isEmpty)
            const _Kosong(teks: 'Belum ada pesanan')
          else
            ...orders.map((o) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(children: [
                    Text(o.id, style: Theme.of(context).textTheme.bodySmall),
                    const Spacer(),
                    Text(o.status.kapital,
                        style: Theme.of(context)
                            .textTheme
                            .labelSmall
                            ?.copyWith(fontWeight: FontWeight.w700)),
                  ]),
                )),
        ],
      ),
    );
  }

  Widget _judul(BuildContext context, String teks) =>
      Padding(
        padding: const EdgeInsets.only(top: 12, bottom: 4),
        child: Text(teks,
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(fontWeight: FontWeight.w700)),
      );
}

class _Kosong extends StatelessWidget {
  const _Kosong({required this.teks});

  final String teks;

  @override
  Widget build(BuildContext context) =>
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Text(teks, style: Theme.of(context).textTheme.bodySmall),
      );
}
