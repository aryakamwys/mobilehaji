import 'package:intl/intl.dart';

/// Format tanggal singkat Indonesia: "27 Okt 2026 14.30".
String tanggalPendek(DateTime d) =>
    DateFormat('d MMM yyyy HH:mm', 'id_ID').format(d);
