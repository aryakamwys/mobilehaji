import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/widgets/labeled_row.dart';
import '../../providers/store_provider.dart';

class ReferralScreen extends ConsumerStatefulWidget {
  const ReferralScreen({super.key});

  @override
  ConsumerState<ReferralScreen> createState() => _ReferralScreenState();
}

class _ReferralScreenState extends ConsumerState<ReferralScreen> {
  final _kode = TextEditingController();

  @override
  void dispose() {
    _kode.dispose();
    super.dispose();
  }

  void _pesan(String msg) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));

  void _bind() {
    try {
      ref.read(storeProvider.notifier).bindReferral(_kode.text);
      _kode.clear();
      _pesan('Referral berhasil dihubungkan');
    } catch (e) {
      _pesan(e.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    final store = ref.watch(storeProvider);
    final member = store.current;
    final sudahUpline = member.parentId != null;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text('Kode Referral Saya',
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        SelectableText(member.referralCode,
            style: Theme.of(context)
                .textTheme
                .headlineSmall
                ?.copyWith(fontFamily: 'monospace', fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: () => SharePlus.instance.share(
              ShareParams(text: 'Gunakan kode referral saya: ${member.referralCode}')),
          icon: const Icon(Icons.share),
          label: const Text('Bagikan Kode'),
        ),
        const Divider(height: 28),
        Text('Jaringan',
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(fontWeight: FontWeight.w700)),
        LabeledRow('Total Downline', '${member.downlines} anggota'),
        LabeledRow('Downline Langsung', '${store.directDownlines.length}'),
        LabeledRow(
            'Pengali Cashback', '${store.factorPreview.toStringAsFixed(2)}x'),
        ...store.directDownlines.map((m) => ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.person_outline),
              title: Text(m.name),
            )),
        const Divider(height: 28),
        if (!sudahUpline) ...[
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
                labelText: 'Kode referral',
                border: OutlineInputBorder()),
          ),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: _bind,
            child: const Text('Hubungkan Referral'),
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
        ...store.rules.map((r) => LabeledRow(
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
