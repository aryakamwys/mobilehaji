import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api_client.dart';
import '../../core/rupiah.dart';
import '../../core/string_ext.dart';
import '../../core/tanggal.dart';
import '../../core/widgets/balance_card.dart';
import '../../models/models.dart';
import '../../providers/data_providers.dart';

class WalletScreen extends ConsumerWidget {
  const WalletScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final wallet = ref.watch(walletProvider);
    final orders = ref.watch(myOrdersProvider).value ?? [];
    return RefreshIndicator(
      onRefresh: () => Future.wait(
          [ref.refresh(walletProvider.future), ref.refresh(myOrdersProvider.future)]),
      child: wallet.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => ListView(padding: const EdgeInsets.all(16), children: [
          _pesanError(context, ref, e),
        ]),
        data: (data) => ListView(
          padding: const EdgeInsets.all(16),
          children: [
            BalanceCard(title: 'Dompet Saya', amount: data.balance),
            _judul(context, 'Inventory Voucher (${data.owned.length})'),
            if (data.owned.isEmpty)
              const _Kosong(teks: 'Belum ada voucher')
            else
              ...data.owned.map((o) => ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(o.title,
                        style: const TextStyle(fontWeight: FontWeight.w700)),
                    subtitle:
                        Text('${o.orderId} • ${tanggalPendek(o.createdAt)}'),
                    trailing: Text('+${o.value.rupiah}',
                        style: TextStyle(
                            color: Colors.green[700],
                            fontWeight: FontWeight.w700)),
                  )),
            const Divider(height: 28),
            _judul(context, 'Mutasi Saldo'),
            if (data.ledger.isEmpty)
              const _Kosong(teks: 'Belum ada mutasi')
            else
              ...data.ledger.map((l) => _MutasiTile(mutasi: l)),
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

  Widget _pesanError(BuildContext context, WidgetRef ref, Object e) => Column(
        children: [
          const SizedBox(height: 24),
          Text(pesanError(e),
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium),
          const SizedBox(height: 8),
          FilledButton.tonal(
              onPressed: () {
                ref.invalidate(walletProvider);
                ref.invalidate(myOrdersProvider);
              },
              child: const Text('Coba Lagi')),
        ],
      );
}

class _MutasiTile extends StatelessWidget {
  const _MutasiTile({required this.mutasi});

  final Ledger mutasi;

  @override
  Widget build(BuildContext context) {
    final masuk = mutasi.amount >= 0;
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(
        masuk ? Icons.arrow_circle_down : Icons.arrow_circle_up,
        color: masuk ? Colors.green[700] : Colors.red[700],
      ),
      title: Text(mutasi.title,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
      subtitle: Text(tanggalPendek(mutasi.createdAt)),
      trailing: Text(
        '${mutasi.amount > 0 ? '+' : ''}${mutasi.amount.rupiah}',
        style: TextStyle(
            fontSize: 14,
            color: masuk ? Colors.green[700] : Colors.red[700],
            fontWeight: FontWeight.w700),
      ),
    );
  }
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
