import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/api_client.dart';
import '../core/token_storage.dart';
import '../models/models.dart';

/// Sesi login saat ini. `null` = belum login.
final authProvider =
    NotifierProvider<AuthController, AsyncValue<Member?>>(AuthController.new);

class AuthController extends Notifier<AsyncValue<Member?>> {
  @override
  AsyncValue<Member?> build() => AsyncValue.data(TokenStorage.member);

  Future<void> login(String email, String password) =>
      _autentikasi('/api/auth/login', {
        'email': email.trim(),
        'password': password,
      });

  Future<void> register(
      String name, String email, String password, String referral) {
    final body = <String, dynamic>{
      'name': name.trim(),
      'email': email.trim(),
      'password': password,
    };
    if (referral.trim().isNotEmpty) body['referral'] = referral.trim();
    return _autentikasi('/api/auth/register', body);
  }

  Future<void> logout() async {
    await TokenStorage.clear();
    state = const AsyncValue.data(null);
  }

  /// Sesi dipaksa keluar (refresh token ditolak server).
  void sesiHabis() => state = const AsyncValue.data(null);

  /// Tandai parentId terisi setelah bind referral sukses, supaya field
  /// referral di checkout langsung hilang tanpa perlu login ulang.
  void tandaiUplineTerikat() {
    final m = state.value;
    if (m == null || m.parentId != null) return;
    state = AsyncValue.data(m.denganParent('terikat'));
  }

  Future<void> _autentikasi(String path, Map<String, dynamic> body) async {
    state = const AsyncValue.loading();
    try {
      final r = await ApiClient.dio.post(path, data: body);
      final data = r.data as Map<String, dynamic>;
      final member = Member.fromJson(data['member'] as Map<String, dynamic>);
      await TokenStorage.save(
        access: data['accessToken'] as String,
        refresh: data['refreshToken'] as String,
        memberBaru: member,
      );
      state = AsyncValue.data(member);
    } on DioException catch (e, st) {
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }
}
