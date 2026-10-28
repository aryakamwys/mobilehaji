import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api_client.dart';
import '../../core/rupiah.dart';
import '../../core/widgets/labeled_row.dart';
import '../../models/models.dart';
import '../../providers/admin_providers.dart';
import 'voucher_editor_sheet.dart';

/// Daftar semua voucher (aktif + nonaktif) dengan aksi admin.
class VouchersScreen extends ConsumerWidget {
  const VouchersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final vouchers = ref.watch(adminVouchersProvider);
    return RefreshIndicator(
      onRefresh: () => ref.refresh(adminVouchersProvider.future),
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          FilledButton.icon(
            onPressed: () => bukaEditorVoucher(context),
            icon: const Icon(Icons.add_circle),
            label: const Text('Tambah Voucher'),
          ),
          const SizedBox(height: 16),
          Text('Semua Voucher',
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
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
                    onPressed: () => ref.invalidate(adminVouchersProvider),
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
                    const Text('Belum ada voucher'),
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

class _VoucherCard extends ConsumerWidget {
  const _VoucherCard({required this.voucher});

  final Voucher voucher;

  void _pesan(BuildContext context, String msg) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));

  Future<void> _toggleAktif(BuildContext context, WidgetRef ref) async {
    try {
      await simpanVoucher(
        id: voucher.id,
        title: voucher.title,
        price: voucher.price,
        value: voucher.value,
        isActive: !voucher.isActive,
      );
      ref.invalidate(adminVouchersProvider);
    } on DioException catch (e) {
      if (context.mounted) _pesan(context, pesanError(e));
    }
  }

  Future<void> _hapus(BuildContext context, WidgetRef ref) async {
    try {
      await hapusVoucher(voucher.id);
      ref.invalidate(adminVouchersProvider);
    } on DioException catch (e) {
      // 409: voucher pernah ditransaksikan — tampilkan pesan server apa adanya.
      if (context.mounted) _pesan(context, pesanError(e));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Card(
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Expanded(
                child: Text(voucher.title,
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(fontWeight: FontWeight.w700)),
              ),
              Text(
                voucher.isActive ? 'Aktif' : 'Nonaktif',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: voucher.isActive
                          ? Colors.green[700]
                          : Theme.of(context).hintColor,
                      fontWeight: FontWeight.w700,
                    ),
              ),
            ]),
            const SizedBox(height: 6),
            LabeledRow('Harga', voucher.price.rupiah),
            LabeledRow('Saldo', voucher.value.rupiah),
            const SizedBox(height: 6),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                OutlinedButton(
                  onPressed: () => bukaEditorVoucher(context, voucher: voucher),
                  child: const Text('Edit'),
                ),
                OutlinedButton(
                  onPressed: () => _toggleAktif(context, ref),
                  child: Text(voucher.isActive ? 'Nonaktifkan' : 'Aktifkan'),
                ),
                OutlinedButton(
                  style:
                      OutlinedButton.styleFrom(foregroundColor: Colors.red[700]),
                  onPressed: () => _hapus(context, ref),
                  child: const Text('Hapus'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
