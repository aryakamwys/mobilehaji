import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/rupiah.dart';
import '../../core/widgets/labeled_row.dart';
import '../../models/models.dart';
import '../../providers/store_provider.dart';

/// Membuka modal checkout untuk voucher terpilih.
void bukaCheckout(BuildContext context, Voucher voucher) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    builder: (_) => CheckoutSheet(voucher: voucher),
  );
}

class CheckoutSheet extends ConsumerStatefulWidget {
  const CheckoutSheet({super.key, required this.voucher});

  final Voucher voucher;

  @override
  ConsumerState<CheckoutSheet> createState() => _CheckoutSheetState();
}

class _CheckoutSheetState extends ConsumerState<CheckoutSheet> {
  final _referral = TextEditingController();
  Order? _order;
  bool _membayar = false;

  @override
  void dispose() {
    _referral.dispose();
    super.dispose();
  }

  void _pesan(String msg) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));

  void _buatOrder() {
    try {
      final order = ref
          .read(storeProvider.notifier)
          .createOrder(widget.voucher, referral: _referral.text);
      setState(() => _order = order);
    } catch (e) {
      _pesan(e.toString());
    }
  }

  /// Fase dummy: meniru pembayaran Midtrans. Produksi: buka snapUrl dari
  /// POST /api/orders lalu poll GET /api/orders/{id}/status.
  Future<void> _bayar() async {
    setState(() => _membayar = true);
    await Future.delayed(const Duration(seconds: 2));
    if (!mounted) return;
    try {
      ref.read(storeProvider.notifier).payOrder(_order!.id);
      _pesan('Pembayaran berhasil, saldo masuk');
      Navigator.of(context).pop();
    } catch (e) {
      _pesan(e.toString());
    } finally {
      if (mounted) setState(() => _membayar = false);
    }
  }

  void _batalkan() {
    try {
      ref.read(storeProvider.notifier).cancelOrder(_order!.id);
      Navigator.of(context).pop();
    } catch (e) {
      _pesan(e.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    final store = ref.watch(storeProvider);
    final bolehReferral = store.current.parentId == null && _order == null;
    return Padding(
      padding:
          EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Checkout',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 16),
            Text('Detail Checkout',
                style: Theme.of(context).textTheme.labelLarge),
            LabeledRow('Voucher', widget.voucher.title),
            LabeledRow('Tagihan', widget.voucher.price.rupiah),
            LabeledRow('Saldo diterima', widget.voucher.value.rupiah,
                valueStyle: TextStyle(
                    color: Colors.green[700], fontWeight: FontWeight.w700)),
            const Divider(height: 28),
            if (bolehReferral) ...[
              TextFormField(
                controller: _referral,
                textCapitalization: TextCapitalization.characters,
                decoration: const InputDecoration(
                    labelText: 'Kode referral (opsional)',
                    border: OutlineInputBorder()),
              ),
              const SizedBox(height: 16),
            ],
            if (_order == null)
              FilledButton.icon(
                onPressed: _buatOrder,
                icon: const Icon(Icons.credit_card),
                label: const Text('Buat Order'),
              )
            else ...[
              LabeledRow('Nomor', _order!.id),
              LabeledRow('Status',
                  _order!.status.capitalize), // pending saat baru dibuat
              const SizedBox(height: 8),
              FilledButton.icon(
                style: FilledButton.styleFrom(
                    backgroundColor: Colors.green[700]),
                onPressed: _membayar ? null : _bayar,
                icon: _membayar
                    ? const SizedBox(
                        height: 18,
                        width: 18,
                        child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.payment),
                label: Text(_membayar
                    ? 'Memproses pembayaran…'
                    : 'Bayar dengan Midtrans'),
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.red[700]),
                onPressed: _batalkan,
                icon: const Icon(Icons.close),
                label: const Text('Batalkan Order'),
              ),
            ],
            const SizedBox(height: 16),
            Text(
              'Pembayaran diproses Midtrans. Status order diperbarui otomatis dari server.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}

extension on String {
  String get capitalize =>
      isEmpty ? this : '${this[0].toUpperCase()}${substring(1)}';
}
