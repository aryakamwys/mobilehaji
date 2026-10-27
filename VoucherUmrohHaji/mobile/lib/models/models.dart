/// Model domain — bentuk field mengikuti respons API backend
/// (lihat docs/superpowers/plans/2026-10-27-flutter-app.md).
/// Fase dummy dibuat oleh MockStore; saat integrasi API tinggal
/// tambahkan factory fromJson di sini tanpa mengubah UI.
library;

class Member {
  Member({
    required this.id,
    required this.name,
    required this.email,
    required this.role,
    required this.referralCode,
    this.parentId,
    this.balance = 0,
    this.downlines = 0,
  });

  String id;
  String name;
  String email;
  String role; // "admin" | "buyer"
  String referralCode;
  String? parentId;
  int balance;
  int downlines;

  bool get isAdmin => role == 'admin';
}

class Voucher {
  Voucher({
    required this.id,
    required this.title,
    required this.price,
    required this.value,
    required this.isActive,
  });

  String id;
  String title;
  int price;
  int value;
  bool isActive;
}

class VoucherOwned {
  VoucherOwned({
    required this.id,
    required this.memberId,
    required this.title,
    required this.value,
    required this.orderId,
    required this.createdAt,
  });

  String id;
  String memberId;
  String title;
  int value;
  String orderId;
  DateTime createdAt;
}

class Ledger {
  Ledger({
    required this.id,
    required this.memberId,
    required this.type,
    required this.title,
    required this.amount,
    required this.orderId,
    required this.createdAt,
  });

  String id;
  String memberId;
  String type; // topup | mlm_cashback | withdraw | refund
  String title;
  int amount; // positif = masuk, negatif = keluar
  String orderId;
  DateTime createdAt;
}

class Withdrawal {
  Withdrawal({
    required this.id,
    required this.memberId,
    required this.amount,
    required this.bank,
    required this.account,
    required this.holder,
    required this.status,
    required this.createdAt,
  });

  String id;
  String memberId;
  int amount;
  String bank;
  String account;
  String holder;
  String status; // pending | approved | rejected
  DateTime createdAt;
}

class Order {
  Order({
    required this.id,
    required this.memberId,
    required this.voucherId,
    required this.amount,
    required this.value,
    required this.status,
    required this.createdAt,
  });

  String id;
  String memberId;
  String voucherId;
  int amount;
  int value;
  String status; // pending | settlement | cancel | expire
  DateTime createdAt;
}

class MlmRule {
  MlmRule({required this.level, required this.percentage});

  int level;
  double percentage;
}

/// Error domain untuk ditampilkan ke user (pesan Bahasa Indonesia).
class AppException implements Exception {
  AppException(this.message);
  final String message;

  @override
  String toString() => message;
}
