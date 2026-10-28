/// Model domain — bentuk field mengikuti respons API backend
/// (lihat docs/superpowers/plans/2026-10-27-flutter-app.md).
/// Field id/memberId hanya dipakai MockStore (fase dummy, dihapus F3);
/// fromJson memetakan respons API apa adanya.
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

  factory Member.fromJson(Map<String, dynamic> j) => Member(
        id: j['id'] as String,
        name: j['name'] as String,
        email: j['email'] as String,
        role: j['role'] as String,
        referralCode: j['referralCode'] as String,
        parentId: j['parentId'] as String?,
        balance: (j['balance'] as num?)?.toInt() ?? 0,
        downlines: (j['downlines'] as num?)?.toInt() ?? 0,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'email': email,
        'role': role,
        'referralCode': referralCode,
        'parentId': parentId,
        'balance': balance,
        'downlines': downlines,
      };

  /// Salinan dengan parentId baru (dipakai setelah bind referral lokal).
  Member denganParent(String parentIdBaru) => Member(
        id: id,
        name: name,
        email: email,
        role: role,
        referralCode: referralCode,
        parentId: parentIdBaru,
        balance: balance,
        downlines: downlines,
      );
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

  factory Voucher.fromJson(Map<String, dynamic> j) => Voucher(
        id: j['id'] as String,
        title: j['title'] as String,
        price: (j['price'] as num).toInt(),
        value: (j['value'] as num).toInt(),
        isActive: j['isActive'] as bool? ?? true,
      );
}

class VoucherOwned {
  VoucherOwned({
    this.id = '',
    this.memberId = '',
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

  factory VoucherOwned.fromJson(Map<String, dynamic> j) => VoucherOwned(
        title: j['title'] as String,
        value: (j['value'] as num).toInt(),
        orderId: j['orderId'] as String,
        createdAt: _tanggal(j['createdAt']),
      );
}

class Ledger {
  Ledger({
    this.id = '',
    this.memberId = '',
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

  factory Ledger.fromJson(Map<String, dynamic> j) => Ledger(
        type: j['type'] as String,
        title: j['title'] as String,
        amount: (j['amount'] as num).toInt(),
        orderId: j['orderId'] as String? ?? '',
        createdAt: _tanggal(j['createdAt']),
      );
}

class Withdrawal {
  Withdrawal({
    this.memberId = '',
    required this.id,
    required this.amount,
    required this.bank,
    required this.account,
    required this.holder,
    required this.status,
    required this.createdAt,
  });

  String memberId;
  String id;
  int amount;
  String bank;
  String account;
  String holder;
  String status; // pending | approved | rejected
  DateTime createdAt;

  factory Withdrawal.fromJson(Map<String, dynamic> j) => Withdrawal(
        id: j['id'] as String,
        amount: (j['amount'] as num).toInt(),
        bank: j['bank'] as String,
        account: j['account'] as String,
        holder: j['holder'] as String,
        status: j['status'] as String,
        createdAt: _tanggal(j['createdAt']),
      );
}

class Order {
  Order({
    required this.id,
    this.memberId = '',
    this.voucherId = '',
    this.voucherTitle,
    this.snapToken,
    this.snapUrl,
    required this.amount,
    required this.value,
    required this.status,
    required this.createdAt,
  });

  String id; // orderId dari backend, format "ORD-…"
  String memberId;
  String voucherId;
  String? voucherTitle;
  String? snapToken;
  String? snapUrl;
  int amount;
  int value;
  String status; // pending | settlement | cancel | expire
  DateTime createdAt;

  /// Melayani respons POST /api/orders (snapToken/snapUrl) dan
  /// item GET /api/orders (voucherTitle/createdAt).
  factory Order.fromJson(Map<String, dynamic> j) => Order(
        id: j['orderId'] as String,
        voucherTitle: j['voucherTitle'] as String?,
        snapToken: j['snapToken'] as String?,
        snapUrl: j['snapUrl'] as String?,
        amount: (j['amount'] as num).toInt(),
        value: (j['value'] as num).toInt(),
        status: j['status'] as String,
        createdAt: _tanggal(j['createdAt']),
      );
}

class MlmRule {
  MlmRule({required this.level, required this.percentage});

  int level;
  double percentage;

  factory MlmRule.fromJson(Map<String, dynamic> j) => MlmRule(
        level: (j['level'] as num).toInt(),
        percentage: (j['percentage'] as num).toDouble(),
      );
}

/// Respons GET /api/referral/me.
class ReferralMe {
  ReferralMe({
    required this.referralCode,
    required this.downlines,
    required this.directDownlines,
    required this.factorPreview,
    this.uplineName,
    required this.rules,
    required this.downlineStep,
    required this.multiplier,
  });

  String referralCode;
  int downlines;
  List<String> directDownlines;
  double factorPreview;
  String? uplineName;
  List<MlmRule> rules;
  int downlineStep;
  double multiplier;

  factory ReferralMe.fromJson(Map<String, dynamic> j) => ReferralMe(
        referralCode: j['referralCode'] as String,
        downlines: (j['downlines'] as num?)?.toInt() ?? 0,
        directDownlines: (j['directDownlines'] as List<dynamic>? ?? [])
            .map((d) => (d as Map<String, dynamic>)['name'] as String? ?? '')
            .where((n) => n.isNotEmpty)
            .toList(),
        factorPreview: (j['factorPreview'] as num?)?.toDouble() ?? 1,
        uplineName: j['uplineName'] as String?,
        rules: (j['rules'] as List<dynamic>? ?? [])
            .map((r) => MlmRule.fromJson(r as Map<String, dynamic>))
            .toList(),
        downlineStep: (j['downlineStep'] as num?)?.toInt() ?? 0,
        multiplier: (j['multiplier'] as num?)?.toDouble() ?? 0,
      );
}

/// Respons GET /api/wallet.
class WalletData {
  WalletData({
    required this.balance,
    required this.owned,
    required this.ledger,
  });

  int balance;
  List<VoucherOwned> owned;
  List<Ledger> ledger;

  factory WalletData.fromJson(Map<String, dynamic> j) => WalletData(
        balance: (j['balance'] as num?)?.toInt() ?? 0,
        owned: (j['owned'] as List<dynamic>? ?? [])
            .map((o) => VoucherOwned.fromJson(o as Map<String, dynamic>))
            .toList(),
        ledger: (j['ledger'] as List<dynamic>? ?? [])
            .map((l) => Ledger.fromJson(l as Map<String, dynamic>))
            .toList(),
      );
}

DateTime _tanggal(dynamic iso) =>
    iso is String ? (DateTime.tryParse(iso)?.toLocal() ?? DateTime.now()) : DateTime.now();

/// Error domain untuk ditampilkan ke user (pesan Bahasa Indonesia).
class AppException implements Exception {
  AppException(this.message);
  final String message;

  @override
  String toString() => message;
}
