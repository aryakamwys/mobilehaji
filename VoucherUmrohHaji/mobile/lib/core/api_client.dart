import 'package:dio/dio.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Dio client ke backend. Base URL dari `.env` (API_BASE_URL).
///
/// Catatan: fase dummy semua data dari MockStore — client ini siap dipakai
/// saat endpoint backend sudah jalan. Interceptor token/refresh ditambah
/// bersamaan dengan integrasi auth sungguhan.
class ApiClient {
  ApiClient._();

  static final Dio dio = Dio(BaseOptions(
    baseUrl: dotenv.env['API_BASE_URL'] ?? 'http://10.0.2.2:5080',
    connectTimeout: const Duration(seconds: 10),
    receiveTimeout: const Duration(seconds: 15),
  ));
}
