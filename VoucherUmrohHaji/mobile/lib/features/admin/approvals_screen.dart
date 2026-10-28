import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api_client.dart';
import '../../core/rupiah.dart';
import '../../core/string_ext.dart';
import '../../core/tanggal.dart';
import '../../models/models.dart';
import '../../providers/admin_providers.dart';

/// Approval penarikan saldo: daftar pending + riwayat keputusan.
class ApprovalsScreen extends ConsumerWidget {
  const ApprovalsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final withdrawals = ref.watch(adminWithdrawalsProvider);
    return RefreshIndicator(
      onRefresh: () => ref.refresh(adminWithdrawalsProvider.future),
      child: withdrawals.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => ListView(padding: const EdgeInsets.all(16), children: [
          const SizedBox(height: 24),
          Text(pesanError(e),
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium),
          const SizedBox(height: 8),
          FilledButton.tonal(
              onPressed: () => ref.invalidate(adminWithdrawalsProvider),
              child: const Text('Coba Lagi')),
        ]),
        data: (list) {
          final pending =
              list.where((w) => w.status == 'pending').toList();
          final riwayat =
              list.where((w) => w.status != 'pending').toList();
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _judul(context, 'Menunggu Approval • ${pending.length}'),
              if (pending.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Text('Tidak ada withdraw pending',
                      style: Theme.of(context).textTheme.bodySmall),
                )
              else
                ...pending.map((w) => Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _WithdrawCard(w: w, aksi: true),
                    )),
              const Divider(height: 28),
              _judul(context, 'Riwayat Approval'),
              ...riwayat.map((w) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _WithdrawCard(w: w, aksi: false),
                  )),
              const SizedBox(height: 8),
              Text(
                'Pastikan dana telah ditransfer secara terpisah sebelum '
                'menyetujui. Tombol Approve tidak menjalankan transfer bank.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _judul(BuildContext context, String teks) => Text(teks,
      style: Theme.of(context)
          .textTheme
          .titleMedium
          ?.copyWith(fontWeight: FontWeight.w700));
}

class _WithdrawCard extends ConsumerWidget {
  const _WithdrawCard({required this.w, required this.aksi});

  final Withdrawal w;
  final bool aksi;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final warna = w.status == 'approved'
        ? Colors.green[700]!
        : w.status == 'rejected'
            ? Colors.red[700]!
            : Colors.orange;
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
                child: Text(w.amount.rupiah,
                    style: Theme.of(context)
                        .textTheme
                        .titleLarge
                        ?.copyWith(fontWeight: FontWeight.w700)),
              ),
              if (!aksi)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: warna.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(w.status.kapital,
                      style: Theme.of(context)
                          .textTheme
                          .labelSmall
                          ?.copyWith(color: warna)),
                ),
            ]),
            const SizedBox(height: 4),
            Text('${w.bank} • ${w.account} • ${w.holder}',
                style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 2),
            Text('${w.id} • ${tanggalPendek(w.createdAt)} • ${w.status.kapital}',
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: Theme.of(context).hintColor)),
            if (aksi) ...[
              const SizedBox(height: 8),
              Row(children: [
                Expanded(
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.red[700]),
                    onPressed: () => _proses(context, ref, false),
                    child: const Text('Tolak'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  flex: 2,
                  child: FilledButton(
                    onPressed: () => _proses(context, ref, true),
                    child: const Text('Setujui (sudah transfer)'),
                  ),
                ),
              ]),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _proses(BuildContext context, WidgetRef ref, bool approve) async {
    try {
      await (approve ? approveWithdrawal(w.id) : rejectWithdrawal(w.id));
      ref.invalidate(adminWithdrawalsProvider);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(approve
                ? 'Penarikan disetujui'
                : 'Penarikan ditolak, saldo dikembalikan')));
      }
    } on DioException catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(pesanError(e))));
      }
    }
  }
}
