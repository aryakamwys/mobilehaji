import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api_client.dart';
import '../../core/rupiah.dart';
import '../../core/widgets/balance_card.dart';
import '../../core/widgets/labeled_row.dart';
import '../../models/models.dart';
import '../../providers/auth_provider.dart';
import '../../providers/data_providers.dart';

import 'checkout_sheet.dart';

class ShopScreen extends ConsumerWidget {
  const ShopScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final member = ref.watch(authProvider).value;
    final wallet = ref.watch(walletProvider);
    final vouchers = ref.watch(vouchersProvider);
    // Sumber saldo tunggal = walletProvider (di-invalidate saat settlement);
    // selama masih loading pakai saldo member terakhir sebagai fallback.
    final saldo = wallet.value?.balance ?? member?.balance ?? 0;
    return RefreshIndicator(
      onRefresh: () async => ref.refresh(vouchersProvider.future),
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          BalanceCard(title: 'Saldo aktif', amount: saldo),
          const SizedBox(height: 8),
          Text(
            'Saldo dan cashback dikreditkan otomatis setelah pembayaran Midtrans berhasil.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 16),
          Text('Paket Voucher',
              style: Theme.of(context)
                  .textTheme
                  .titleLarge
                  ?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          Text('Pilih voucher untuk membeli dan membayar via Midtrans.',
              style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 12),
          vouchers.when(
            loading: () => const Padding(
              padding: EdgeInsets.symmetric(vertical: 40),
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (e, _) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Column(children: [
                Text(pesanError(e),
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium),
                const SizedBox(height: 8),
                FilledButton.tonal(
                    onPressed: () => ref.invalidate(vouchersProvider),
                    child: const Text('Coba Lagi')),
              ]),
            ),
            data: (daftar) {
              if (daftar.isEmpty) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 40),
                  child: Column(children: [
                    Icon(Icons.card_giftcard_outlined,
                        size: 48, color: Theme.of(context).disabledColor),
                    const SizedBox(height: 8),
                    const Text('Belum ada voucher aktif'),
                  ]),
                );
              }
              return Column(
                children: daftar
                    .map((v) => Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: _VoucherCard(voucher: v),
                        ))
                    .toList(),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _VoucherCard extends StatelessWidget {
  const _VoucherCard({required this.voucher});

  final Voucher voucher;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Icon(Icons.card_giftcard,
                  color: Theme.of(context).colorScheme.primary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(voucher.title,
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(fontWeight: FontWeight.w700)),
              ),
            ]),
            const SizedBox(height: 10),
            LabeledRow('Harga bayar', voucher.price.rupiah),
            LabeledRow('Saldo diterima', voucher.value.rupiah,
                valueStyle: TextStyle(
                    color: Colors.green[700], fontWeight: FontWeight.w700)),
            const SizedBox(height: 6),
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton(
                onPressed: () => bukaCheckout(context, voucher),
                child: const Text('Beli Voucher'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
