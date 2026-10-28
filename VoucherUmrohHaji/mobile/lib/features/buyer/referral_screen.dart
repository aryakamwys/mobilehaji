import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/api_client.dart';
import '../../core/widgets/labeled_row.dart';
import '../../models/models.dart';
import '../../providers/auth_provider.dart';
import '../../providers/data_providers.dart';

class ReferralScreen extends ConsumerStatefulWidget {
  const ReferralScreen({super.key});

  @override
  ConsumerState<ReferralScreen> createState() => _ReferralScreenState();
}

class _ReferralScreenState extends ConsumerState<ReferralScreen> {
  final _kode = TextEditingController();
  bool _mengikat = false;

  @override
  void dispose() {
    _kode.dispose();
    super.dispose();
  }

  void _pesan(String msg) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));

  Future<void> _bind() async {
    final kode = _kode.text.trim();
    if (kode.isEmpty) {
      _pesan('Isi kode referral upline');
      return;
    }
    setState(() => _mengikat = true);
    try {
      await bindReferral(kode);
      ref.read(authProvider.notifier).tandaiUplineTerikat();
      ref.invalidate(referralMeProvider);
      _kode.clear();
      if (mounted) _pesan('Referral berhasil dihubungkan');
    } on DioException catch (e) {
      if (mounted) _pesan(pesanError(e));
    } finally {
      if (mounted) setState(() => _mengikat = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final referral = ref.watch(referralMeProvider);
    return RefreshIndicator(
      onRefresh: () async => ref.refresh(referralMeProvider.future),
      child: referral.when(
        loading: () => ListView(children: const [
          Padding(
            padding: EdgeInsets.symmetric(vertical: 60),
            child: Center(child: CircularProgressIndicator()),
          ),
        ]),
        error: (e, _) => ListView(children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(children: [
              const SizedBox(height: 16),
              Text(pesanError(e),
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium),
              const SizedBox(height: 8),
              FilledButton.tonal(
                  onPressed: () => ref.invalidate(referralMeProvider),
                  child: const Text('Coba Lagi')),
            ]),
          ),
        ]),
        data: (data) => _isi(context, data),
      ),
    );
  }

  Widget _isi(BuildContext context, ReferralMe data) {
    final belumUpline = data.uplineName == null;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text('Kode Referral Saya',
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        SelectableText(data.referralCode,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontFamily: 'monospace', fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: () => SharePlus.instance.share(
              ShareParams(text: 'Gunakan kode referral saya: ${data.referralCode}')),
          icon: const Icon(Icons.share),
          label: const Text('Bagikan Kode'),
        ),
        const Divider(height: 28),
        Text('Jaringan',
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(fontWeight: FontWeight.w700)),
        LabeledRow('Total Downline', '${data.downlines} anggota'),
        LabeledRow('Downline Langsung', '${data.directDownlines.length}'),
        LabeledRow(
            'Pengali Cashback', '${data.factorPreview.toStringAsFixed(2)}x'),
        ...data.directDownlines.map((nama) => ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.person_outline),
              title: Text(nama),
            )),
        const Divider(height: 28),
        if (belumUpline) ...[
          Text('Hubungkan Upline',
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          TextFormField(
            controller: _kode,
            textCapitalization: TextCapitalization.characters,
            decoration: const InputDecoration(
                labelText: 'Kode referral', border: OutlineInputBorder()),
          ),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: _mengikat ? null : _bind,
            child: _mengikat
                ? const SizedBox(
                    height: 18,
                    width: 18,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : const Text('Hubungkan Referral'),
          ),
        ] else
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(Icons.verified, color: Colors.green[700]),
            title: const Text('Akun terhubung dengan upline'),
          ),
        const Divider(height: 28),
        Text('Persentase MLM',
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(fontWeight: FontWeight.w700)),
        ...data.rules.map((r) => LabeledRow(
            'Level ${r.level}', '${r.percentage.toStringAsFixed(2)}%')),
        const SizedBox(height: 4),
        Text(
          'Cashback = Harga Bayar × Persentase Level × (1 + ⌊Total Downline / Step⌋ × Faktor)',
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }
}
