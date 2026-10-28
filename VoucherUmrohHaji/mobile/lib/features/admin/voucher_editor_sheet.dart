import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api_client.dart';
import '../../models/models.dart';
import '../../providers/admin_providers.dart';

/// Membuka editor voucher (null = voucher baru) sebagai modal bottom sheet.
void bukaEditorVoucher(BuildContext context, {Voucher? voucher}) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    builder: (_) => VoucherEditorSheet(voucher: voucher),
  );
}

class VoucherEditorSheet extends ConsumerStatefulWidget {
  const VoucherEditorSheet({super.key, this.voucher});

  final Voucher? voucher;

  @override
  ConsumerState<VoucherEditorSheet> createState() => _VoucherEditorSheetState();
}

class _VoucherEditorSheetState extends ConsumerState<VoucherEditorSheet> {
  late final _nama = TextEditingController(text: widget.voucher?.title ?? '');
  late final _harga = TextEditingController(
      text: widget.voucher != null ? '${widget.voucher!.price}' : '');
  late final _saldo = TextEditingController(
      text: widget.voucher != null ? '${widget.voucher!.value}' : '');
  late bool _aktif = widget.voucher?.isActive ?? true;
  bool _menyimpan = false;

  static const _pesanValidasi = 'Isi nama paket dan angka lebih dari 0';

  @override
  void dispose() {
    _nama.dispose();
    _harga.dispose();
    _saldo.dispose();
    super.dispose();
  }

  void _pesan(String msg) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));

  Future<void> _simpan() async {
    final nama = _nama.text.trim();
    final harga = int.tryParse(_harga.text.trim());
    final saldo = int.tryParse(_saldo.text.trim());
    if (nama.isEmpty ||
        harga == null ||
        harga <= 0 ||
        saldo == null ||
        saldo <= 0) {
      _pesan(_pesanValidasi);
      return;
    }
    setState(() => _menyimpan = true);
    try {
      await simpanVoucher(
        id: widget.voucher?.id,
        title: nama,
        price: harga,
        value: saldo,
        isActive: _aktif,
      );
      ref.invalidate(adminVouchersProvider);
      if (mounted) Navigator.of(context).pop();
    } on DioException catch (e) {
      if (mounted) {
        setState(() => _menyimpan = false);
        _pesan(pesanError(e));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Stack(
              alignment: Alignment.center,
              children: [
                Text(
                  widget.voucher == null ? 'Voucher Baru' : 'Edit Voucher',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Tutup'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _nama,
              decoration: const InputDecoration(
                  labelText: 'Nama paket', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _harga,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                  labelText: 'Harga bayar', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _saldo,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                  labelText: 'Nilai saldo diterima',
                  border: OutlineInputBorder()),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Aktif'),
              value: _aktif,
              onChanged: (v) => setState(() => _aktif = v),
            ),
            const SizedBox(height: 8),
            FilledButton(
              onPressed: _menyimpan ? null : _simpan,
              child: Text(_menyimpan ? 'Menyimpan…' : 'Simpan Voucher'),
            ),
          ],
        ),
      ),
    );
  }
}
