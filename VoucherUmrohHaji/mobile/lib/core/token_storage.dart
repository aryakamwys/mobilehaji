import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../models/models.dart';

/// Penyimpanan aman sesi login: access/refresh token + data member.
///
/// Cache statis diisi oleh [load] saat startup (sebelum runApp) supaya
/// interceptor Dio bisa memasang header Authorization secara sinkron.
class TokenStorage {
  TokenStorage._();

  static const _box = FlutterSecureStorage();

  static const _kAccess = 'accessToken';
  static const _kRefresh = 'refreshToken';
  static const _kMember = 'memberJson';

  static String? accessToken;
  static String? refreshToken;
  static Member? member;

  static bool get adaSesi => accessToken != null && refreshToken != null;

  /// Membaca storage ke cache — dipanggil sekali di main().
  static Future<void> load() async {
    final access = await _box.read(key: _kAccess);
    final refresh = await _box.read(key: _kRefresh);
    final memberJson = await _box.read(key: _kMember);
    accessToken = access;
    refreshToken = refresh;
    if (memberJson != null) {
      try {
        member = Member.fromJson(jsonDecode(memberJson) as Map<String, dynamic>);
      } on FormatException {
        member = null;
      }
    }
  }

  static Future<void> save({
    required String access,
    required String refresh,
    required Member memberBaru,
  }) async {
    accessToken = access;
    refreshToken = refresh;
    member = memberBaru;
    await _box.write(key: _kAccess, value: access);
    await _box.write(key: _kRefresh, value: refresh);
    await _box.write(key: _kMember, value: jsonEncode(memberBaru.toJson()));
  }

  /// Perbarui data member tersimpan (mis. parentId setelah bind referral)
  /// tanpa mengubah token.
  static Future<void> updateMember(Member memberBaru) async {
    member = memberBaru;
    await _box.write(key: _kMember, value: jsonEncode(memberBaru.toJson()));
  }

  static Future<void> clear() async {
    accessToken = null;
    refreshToken = null;
    member = null;
    await _box.delete(key: _kAccess);
    await _box.delete(key: _kRefresh);
    await _box.delete(key: _kMember);
  }
}
