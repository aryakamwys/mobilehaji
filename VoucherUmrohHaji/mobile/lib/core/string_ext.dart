/// "pending" → "Pending" (setara .capitalized di Swift).
extension CapitalizeString on String {
  String get kapital =>
      isEmpty ? this : '${this[0].toUpperCase()}${substring(1).toLowerCase()}';
}
