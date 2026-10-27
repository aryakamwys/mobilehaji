import 'package:intl/intl.dart';

/// Format Rupiah tanpa desimal: 150000 → "Rp 150.000".
extension RupiahFormat on int {
  static final NumberFormat _angka = NumberFormat('#,##0', 'id_ID');

  String get rupiah => 'Rp ${_angka.format(this)}';
}
