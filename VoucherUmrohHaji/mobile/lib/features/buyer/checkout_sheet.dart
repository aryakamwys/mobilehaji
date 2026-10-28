import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api_client.dart';
import '../../core/rupiah.dart';
import '../../core/string_ext.dart';
import '../../core/widgets/labeled_row.dart';
import '../../models/models.dart';
import '../../providers/auth_provider.dart';
import '../../providers/data_providers.dart';
import 'pembayaran_webview.dart';

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
  bool _membuat = false;
  bool _membayar = false;

  static const _maxPoll = 10;
  static const _jarakPoll = Duration(seconds: 3);

  @override
  void dispose() {
    _referral.dispose();
    super.dispose();
  }

  void _pesan(String msg, {Color? warna}) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(msg, style: const TextStyle(color: Colors.white)),
          backgroundColor: warna));

  Future<void> _buatOrder() async {
    setState(() => _membuat = true);
    try {
      final kode = _referral.text.trim();
      if (kode.isNotEmpty) {
        // Referral wajib diikat DULU — kalau gagal, order tidak dibuat.
        await bindReferral(kode);
        ref.read(authProvider.notifier).tandaiUplineTerikat();
        // Tab Referal (IndexedStack, tetap mounted) harus tahu upline terikat.
        ref.invalidate(referralMeProvider);
      }
      final order = await buatOrder(widget.voucher);
      ref.invalidate(myOrdersProvider);
      if (mounted) setState(() => _order = order);
    } on DioException catch (e) {
      if (mounted) _pesan(pesanError(e));
    } finally {
      if (mounted) setState(() => _membuat = false);
    }
  }

  Future<void> _bayar() async {
    final url = Uri.tryParse(_order?.snapUrl ?? '');
    if (_order == null || url == null || !url.hasAuthority) {
      _pesan('Halaman pembayaran tidak tersedia untuk order ini');
      return; // tanpa Snap URL valid, poll 30 detik sia-sia
    }
    setState(() => _membayar = true);
    try {
      // Snap ditampilkan di dalam app (WebView); skema app pembayaran
      // (gopay:// dll) otomatis diteruskan ke app eksternal oleh WebView.
      await Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => PembayaranWebView(url: url.toString()),
      ));
    } on Exception {
      if (!mounted) return;
      setState(() => _membayar = false);
      _pesan('Tidak dapat membuka halaman pembayaran Midtrans');
      return; // Snap tidak terbuka — jangan mulai poll
    }
    for (var i = 0; i < _maxPoll; i++) {
      await Future.delayed(_jarakPoll);
      if (!mounted) return;
      final status = await _cekStatus(); // null = gagal cek, lanjut poll
      if (!mounted) return;
      if (status == null) continue;
      if (status == 'settlement') {
        _refreshSemua();
        _pesan('Pembayaran berhasil, saldo masuk', warna: Colors.green[700]);
        Navigator.of(context).pop();
        return;
      }
      if (status == 'cancel' || status == 'expire') {
        _refreshSemua();
        _pesan(status == 'cancel'
            ? 'Order dibatalkan'
            : 'Order kedaluwarsa, silakan buat order baru');
        Navigator.of(context).pop();
        return;
      }
    }
    if (!mounted) return;
    _refreshSemua();
    setState(() => _membayar = false);
    _pesan('Status pembayaran belum berubah — cek tab Dompet nanti');
  }

  Future<String?> _cekStatus() async {
    try {
      return await statusOrder(_order!.id);
    } on Exception {
      return null; // jaringan sempat gagal → coba poll berikutnya
    }
  }

  void _refreshSemua() {
    ref.invalidate(walletProvider);
    ref.invalidate(vouchersProvider);
    ref.invalidate(myOrdersProvider);
    ref.invalidate(referralMeProvider);
  }

  Future<void> _batalkan() async {
    try {
      await batalkanOrder(_order!.id);
      _refreshSemua();
      if (mounted) Navigator.of(context).pop();
    } on DioException catch (e) {
      if (mounted) _pesan(pesanError(e));
    }
  }

  @override
  Widget build(BuildContext context) {
    final member = ref.watch(authProvider).value;
    final bolehReferral = (member?.parentId == null) && _order == null;
    return Padding(
      padding:
          EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Stack(
              alignment: Alignment.center,
              children: [
                Text('Checkout',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.titleMedium),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('Tutup')),
                ),
              ],
            ),
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
              Text('Kode referral (opsional)',
                  style: Theme.of(context).textTheme.labelLarge),
              const SizedBox(height: 8),
              TextFormField(
                controller: _referral,
                textCapitalization: TextCapitalization.characters,
                decoration: const InputDecoration(
                    hintText: 'Kode referral upline',
                    border: OutlineInputBorder()),
              ),
              const SizedBox(height: 16),
            ],
            if (_order == null)
              FilledButton.icon(
                onPressed: _membuat ? null : _buatOrder,
                icon: _membuat
                    ? const SizedBox(
                        height: 18,
                        width: 18,
                        child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.credit_card),
                label: Text(_membuat ? 'Membuat order…' : 'Buat Order'),
              )
            else ...[
              Text('Order', style: Theme.of(context).textTheme.labelLarge),
              LabeledRow('Nomor', _order!.id),
              LabeledRow('Status', _order!.status.kapital),
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
                    ? 'Memeriksa pembayaran…'
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
