import 'package:dio/dio.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import 'token_storage.dart';

/// Dio client ke backend. Base URL dari `.env` (API_BASE_URL);
/// semua request memakai path relatif `/api/...`.
class ApiClient {
  ApiClient._();

  static String get baseUrl => dotenv.env['API_BASE_URL'] ?? 'http://10.0.2.2:5038';

  static final Dio dio = _buat();

  /// Dipasang main(): dipanggil saat refresh token gagal → sesi hangus.
  static void Function()? onSessionExpired;

  static Dio _buat() {
    final d = Dio(BaseOptions(
      baseUrl: baseUrl,
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 20),
    ));
    d.interceptors.add(_AuthInterceptor(d));
    return d;
  }
}

class _AuthInterceptor extends QueuedInterceptor {
  _AuthInterceptor(this._dio);

  final Dio _dio;

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    final token = TokenStorage.accessToken;
    if (token != null) {
      options.headers['Authorization'] = 'Bearer $token';
    }
    handler.next(options);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) async {
    final req = err.requestOptions;
    final status = err.response?.statusCode;
    final adalahAuth = req.path.startsWith('/api/auth/');
    if (status != 401 || adalahAuth || req.extra['dicobaLagi'] == true) {
      return handler.reject(err);
    }
    try {
      final berhasil = await _refreshToken();
      if (!berhasil) throw StateError('refresh gagal');
      req.extra['dicobaLagi'] = true;
      req.headers['Authorization'] = 'Bearer ${TokenStorage.accessToken}';
      final response = await _dio.fetch(req);
      return handler.resolve(response);
    } catch (_) {
      await TokenStorage.clear();
      ApiClient.onSessionExpired?.call();
      return handler.reject(err);
    }
  }

  /// POST /api/auth/refresh lewat Dio polos (tanpa interceptor, anti-loop).
  Future<bool> _refreshToken() async {
    final refresh = TokenStorage.refreshToken;
    if (refresh == null) return false;
    final polos = Dio(BaseOptions(baseUrl: ApiClient.baseUrl))
      ..options.connectTimeout = const Duration(seconds: 10)
      ..options.receiveTimeout = const Duration(seconds: 10);
    try {
      final r = await polos.post('/api/auth/refresh',
          data: {'refreshToken': refresh});
      final data = r.data as Map<String, dynamic>;
      final access = data['accessToken'] as String?;
      final baru = data['refreshToken'] as String?;
      if (access == null || baru == null) return false;
      await TokenStorage.save(
          access: access, refresh: baru, memberBaru: TokenStorage.member!);
      return true;
    } on DioException {
      return false;
    }
  }
}

/// Pesan error siap tampil dari exception apa pun.
/// Backend selalu membalas `{ "error": "pesan" }` saat gagal.
String pesanError(Object e) {
  if (e is DioException) {
    final data = e.response?.data;
    if (data is Map && data['error'] is String) return data['error'] as String;
    return switch (e.type) {
      DioExceptionType.connectionTimeout ||
      DioExceptionType.connectionError =>
        'Tidak dapat terhubung ke server',
      DioExceptionType.receiveTimeout ||
      DioExceptionType.sendTimeout =>
        'Server tidak merespons, coba lagi',
      _ => 'Terjadi kesalahan jaringan',
    };
  }
  return e.toString();
}

/// Ubah respons API berupa list JSON jadi `List<T>`; null/absen → list kosong.
List<T> daftarDariJson<T>(
        dynamic data, T Function(Map<String, dynamic>) dariJson) =>
    (data as List<dynamic>? ?? [])
        .map((j) => dariJson(j as Map<String, dynamic>))
        .toList();
