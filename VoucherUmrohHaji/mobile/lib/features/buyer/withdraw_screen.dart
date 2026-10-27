import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/rupiah.dart';
import '../../core/tanggal.dart';
import '../../core/widgets/balance_card.dart';
import '../../providers/store_provider.dart';

class WithdrawScreen extends ConsumerStatefulWidget {
  const WithdrawScreen({super.key});

  @override
  ConsumerState<WithdrawScreen> createState() => _WithdrawScreenState();
}

class _WithdrawScreenState extends ConsumerState<WithdrawScreen> {
  final _amount = TextEditingController();
  final _bank = TextEditingController();
  final _account = TextEditingController();
  final _holder = TextEditingController();

  @override
  void dispose() {
    _amount.dispose();
    _bank.dispose();
    _account.dispose();
    _holder.dispose();
    super.dispose();
  }

  void _pesan(String msg) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));

  void _ajukan() {
    final nominal = int.tryParse(_amount.text.replaceAll(RegExp(r'[^0-9]'), ''));
    if (nominal == null || nominal <= 0) {
      _pesan('Isi nominal penarikan');
      return;
    }
    try {
      ref.read(storeProvider.notifier).requestWithdrawal(
          nominal, _bank.text, _account.text, _holder.text);
      _amount.clear();
      _bank.clear();
      _account.clear();
      _holder.clear();
      _pesan('Pengajuan terkirim, menunggu approval admin');
    } catch (e) {
      _pesan(e.toString());
    }
  }

  Color? _warnaStatus(String status) => switch (status) {
        'approved' => Colors.green[700],
        'rejected' => Colors.red[700],
        _ => Colors.orange,
      };

  @override
  Widget build(BuildContext context) {
    final store = ref.watch(storeProvider);
    final withdrawals = store.userWithdrawals;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        BalanceCard(title: 'Saldo Tersedia', amount: store.current.balance),
        const SizedBox(height: 16),
        Text('Ajukan Withdraw',
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        TextFormField(
          controller: _amount,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
              labelText: 'Nominal (Rp)', border: OutlineInputBorder()),
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: _bank,
          decoration: const InputDecoration(
              labelText: 'Nama bank / e-wallet', border: OutlineInputBorder()),
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: _account,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
              labelText: 'Nomor rekening', border: OutlineInputBorder()),
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: _holder,
          decoration: const InputDecoration(
              labelText: 'Nama pemilik rekening', border: OutlineInputBorder()),
        ),
        const SizedBox(height: 16),
        FilledButton.icon(
          onPressed: _ajukan,
          icon: const Icon(Icons.outbound),
          label: const Text('Ajukan Penarikan'),
        ),
        const Divider(height: 28),
        Text('Status Penarikan',
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(fontWeight: FontWeight.w700)),
        if (withdrawals.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text('Belum ada permintaan penarikan',
                style: Theme.of(context).textTheme.bodySmall),
          )
        else
          ...withdrawals.map((w) => ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(w.amount.rupiah,
                    style: const TextStyle(fontWeight: FontWeight.w700)),
                subtitle: Text(
                    '${w.bank} • ${w.account} • ${tanggalPendek(w.createdAt)}'),
                trailing: Text(
                    w.status == 'approved'
                        ? 'Approved'
                        : w.status == 'rejected'
                            ? 'Rejected'
                            : 'Pending',
                    style: TextStyle(
                        color: _warnaStatus(w.status),
                        fontWeight: FontWeight.w700)),
              )),
        const SizedBox(height: 8),
        Text(
          'Permintaan menahan saldo hingga admin menyetujui atau menolak.',
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }
}
