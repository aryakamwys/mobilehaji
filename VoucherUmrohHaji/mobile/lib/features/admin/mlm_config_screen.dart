import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api_client.dart';
import '../../models/models.dart';
import '../../providers/admin_providers.dart';
import '../../providers/data_providers.dart';

/// Konfigurasi komisi MLM — level persentase, step downline, multiplier.
/// Prefill dari GET /api/referral/me.
class MlmConfigScreen extends ConsumerWidget {
  const MlmConfigScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final config = ref.watch(referralMeProvider);
    return config.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(pesanError(e),
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium),
            const SizedBox(height: 8),
            FilledButton.tonal(
                onPressed: () => ref.invalidate(referralMeProvider),
                child: const Text('Coba Lagi')),
          ],
        ),
      ),
      data: (data) => _MlmConfigForm(config: data),
    );
  }
}

class _MlmConfigForm extends ConsumerStatefulWidget {
  const _MlmConfigForm({required this.config});

  final ReferralMe config;

  @override
  ConsumerState<_MlmConfigForm> createState() => _MlmConfigFormState();
}

class _MlmConfigFormState extends ConsumerState<_MlmConfigForm> {
  late final List<TextEditingController> _persen = widget.config.rules
      .map((r) => TextEditingController(text: _angka(r.percentage)))
      .toList();
  late final _step =
      TextEditingController(text: '${widget.config.downlineStep}');
  late final _faktor =
      TextEditingController(text: _angka(widget.config.multiplier));
  bool _menyimpan = false;

  /// 5.0 → "5", 0.5 → "0.5" (sama seperti String(Double) di Swift).
  static String _angka(double n) =>
      n % 1 == 0 ? n.toInt().toString() : n.toString();

  double? _desimal(String s) =>
      double.tryParse(s.trim().replaceAll(',', '.'));

  @override
  void dispose() {
    for (final c in _persen) {
      c.dispose();
    }
    _step.dispose();
    _faktor.dispose();
    super.dispose();
  }

  void _pesan(String msg) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));

  Future<void> _simpan() async {
    final levels =
        _persen.map((c) => _desimal(c.text)).toList();
    final step = int.tryParse(_step.text.trim());
    final faktor = _desimal(_faktor.text);
    if (levels.any((l) => l == null || l < 0) ||
        step == null ||
        step <= 0 ||
        faktor == null ||
        faktor < 0) {
      _pesan('Konfigurasi komisi tidak valid');
      return;
    }
    setState(() => _menyimpan = true);
    try {
      await simpanMlmConfig(levels.cast<double>(), step, faktor);
      ref.invalidate(referralMeProvider);
      if (mounted) _pesan('Konfigurasi tersimpan');
    } on DioException catch (e) {
      if (mounted) _pesan(pesanError(e));
    } finally {
      if (mounted) setState(() => _menyimpan = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text('Persentase Cashback per Level',
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        for (var i = 0; i < _persen.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(children: [
              SizedBox(
                width: 84,
                child: Text('Level ${i + 1}',
                    style: Theme.of(context).textTheme.bodyMedium),
              ),
              Expanded(
                child: TextFormField(
                  controller: _persen[i],
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  textAlign: TextAlign.right,
                  decoration: const InputDecoration(
                      suffixText: '%', border: OutlineInputBorder()),
                ),
              ),
            ]),
          ),
        Row(children: [
          TextButton(
            onPressed: _persen.length >= 20
                ? null
                : () => setState(
                    () => _persen.add(TextEditingController(text: '0'))),
            child: const Text('Tambah Level'),
          ),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: Colors.red[700]),
            onPressed: _persen.length <= 1
                ? null
                : () => setState(() {
                      final c = _persen.removeLast();
                      c.dispose();
                    }),
            child: const Text('Hapus Level Terakhir'),
          ),
        ]),
        const Divider(height: 28),
        Text('Bonus Multiplier',
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        TextFormField(
          controller: _step,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
              labelText: 'Kelipatan jumlah downline',
              border: OutlineInputBorder()),
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: _faktor,
          keyboardType:
              const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(
              labelText: 'Tambahan faktor per kelipatan',
              border: OutlineInputBorder()),
        ),
        const SizedBox(height: 8),
        Text(
          'Contoh: 2 downline dengan faktor 0.5 menghasilkan pengali 1.5×.',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: 16),
        FilledButton(
          onPressed: _menyimpan ? null : _simpan,
          child: Text(_menyimpan ? 'Menyimpan…' : 'Simpan Konfigurasi'),
        ),
      ],
    );
  }
}
