import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/api_client.dart';
import '../models/models.dart';

/// Respons GET /api/admin/members.
class MembersPage {
  MembersPage({required this.items, required this.totalPages});

  final List<Member> items;
  final int totalPages;

  factory MembersPage.fromJson(Map<String, dynamic> j) => MembersPage(
        items: (j['items'] as List<dynamic>? ?? [])
            .map((m) => Member.fromJson(m as Map<String, dynamic>))
            .toList(),
        totalPages: (j['totalPages'] as num?)?.toInt() ?? 1,
      );
}

/// Semua voucher termasuk nonaktif, urut judul — GET /api/admin/vouchers.
final adminVouchersProvider =
    FutureProvider.autoDispose<List<Voucher>>((ref) async {
  final r = await ApiClient.dio.get('/api/admin/vouchers');
  return daftarDariJson(r.data, Voucher.fromJson);
});

/// Semua pengajuan withdraw (pending dulu) — GET /api/admin/withdrawals.
final adminWithdrawalsProvider =
    FutureProvider.autoDispose<List<Withdrawal>>((ref) async {
  final r = await ApiClient.dio.get('/api/admin/withdrawals');
  return daftarDariJson(r.data, Withdrawal.fromJson);
});

/// Satu halaman (20 baris) daftar anggota — GET /api/admin/members?page=n.
final adminMembersPageProvider =
    FutureProvider.autoDispose.family<MembersPage, int>((ref, page) async {
  final r = await ApiClient.dio.get('/api/admin/members',
      queryParameters: {'page': page, 'pageSize': 20});
  return MembersPage.fromJson(r.data as Map<String, dynamic>);
});

/// POST (id null) / PUT /api/admin/vouchers/{id}.
Future<void> simpanVoucher({
  String? id,
  required String title,
  required int price,
  required int value,
  required bool isActive,
}) async {
  final body = {
    'title': title.trim(),
    'price': price,
    'value': value,
    if (id != null) 'isActive': isActive,
  };
  if (id == null) {
    await ApiClient.dio.post('/api/admin/vouchers', data: body);
  } else {
    await ApiClient.dio.put('/api/admin/vouchers/$id', data: body);
  }
}

/// DELETE /api/admin/vouchers/{id} — 409 bila voucher pernah ditransaksikan.
Future<void> hapusVoucher(String id) async {
  await ApiClient.dio.delete('/api/admin/vouchers/$id');
}

/// PUT /api/admin/mlm-config — persentase per level, step, multiplier.
Future<void> simpanMlmConfig(
    List<double> levels, int downlineStep, double multiplier) async {
  await ApiClient.dio.put('/api/admin/mlm-config', data: {
    'levels': levels,
    'downlineStep': downlineStep,
    'multiplier': multiplier,
  });
}

/// POST /api/admin/withdrawals/{id}/approve — konfirmasi dana sudah transfer.
Future<void> approveWithdrawal(String id) async {
  await ApiClient.dio.post('/api/admin/withdrawals/$id/approve');
}

/// POST /api/admin/withdrawals/{id}/reject — saldo dikembalikan ke member.
Future<void> rejectWithdrawal(String id) async {
  await ApiClient.dio.post('/api/admin/withdrawals/$id/reject');
}
