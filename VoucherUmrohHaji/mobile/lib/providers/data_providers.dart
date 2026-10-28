import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/api_client.dart';
import '../models/models.dart';

List<T> _daftar<T>(dynamic data, T Function(Map<String, dynamic>) dariJson) =>
    (data as List<dynamic>? ?? [])
        .map((j) => dariJson(j as Map<String, dynamic>))
        .toList();

/// Katalog voucher aktif — GET /api/vouchers.
final vouchersProvider =
    FutureProvider.autoDispose<List<Voucher>>((ref) async {
  final r = await ApiClient.dio.get('/api/vouchers');
  return _daftar(r.data, Voucher.fromJson);
});

/// Saldo, inventory voucher, mutasi — GET /api/wallet.
final walletProvider = FutureProvider.autoDispose<WalletData>((ref) async {
  final r = await ApiClient.dio.get('/api/wallet');
  return WalletData.fromJson(r.data as Map<String, dynamic>);
});

/// Data referral member login — GET /api/referral/me.
final referralMeProvider =
    FutureProvider.autoDispose<ReferralMe>((ref) async {
  final r = await ApiClient.dio.get('/api/referral/me');
  return ReferralMe.fromJson(r.data as Map<String, dynamic>);
});

/// Riwayat pengajuan withdraw — GET /api/withdrawals.
final withdrawalsProvider =
    FutureProvider.autoDispose<List<Withdrawal>>((ref) async {
  final r = await ApiClient.dio.get('/api/withdrawals');
  return _daftar(r.data, Withdrawal.fromJson);
});

/// Daftar pesanan sendiri (terbaru dulu) — GET /api/orders.
final myOrdersProvider = FutureProvider.autoDispose<List<Order>>((ref) async {
  final r = await ApiClient.dio.get('/api/orders');
  return _daftar(r.data, Order.fromJson);
});

/// POST /api/referral/bind — mengikat upline dari kode referral.
Future<void> bindReferral(String kode) async {
  await ApiClient.dio
      .post('/api/referral/bind', data: {'referralCode': kode.trim()});
}

/// POST /api/orders — buat order + token Midtrans Snap.
Future<Order> buatOrder(Voucher voucher) async {
  final r = await ApiClient.dio
      .post('/api/orders', data: {'voucherId': voucher.id});
  return Order.fromJson(r.data as Map<String, dynamic>);
}

/// POST /api/orders/{id}/cancel — batalkan order pending.
Future<void> batalkanOrder(String orderId) async {
  await ApiClient.dio.post('/api/orders/$orderId/cancel');
}

/// GET /api/orders/{id}/status — status terkini (memicu inquiry di backend).
Future<String> statusOrder(String orderId) async {
  final r = await ApiClient.dio.get('/api/orders/$orderId/status');
  return (r.data as Map<String, dynamic>)['status'] as String? ?? 'pending';
}

/// POST /api/withdrawals — ajukan penarikan saldo.
Future<void> ajukanWithdrawal(
    int amount, String bank, String account, String holder) async {
  await ApiClient.dio.post('/api/withdrawals', data: {
    'amount': amount,
    'bank': bank.trim(),
    'account': account.trim(),
    'holder': holder.trim(),
  });
}
