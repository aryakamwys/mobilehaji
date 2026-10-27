import 'package:flutter_riverpod/legacy.dart';

import '../mock/mock_store.dart';

/// Sumber data app. Fase dummy: MockStore (port demo Swift).
/// Saat backend jadi, ganti isi provider ini dengan implementasi API
/// (dio) — UI dan model tidak berubah.
final storeProvider = ChangeNotifierProvider<MockStore>((ref) => MockStore());
