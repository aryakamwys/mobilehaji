import 'dart:math';

import 'package:flutter/foundation.dart';

import '../models/models.dart';

/// State dummy — port dari demo SwiftUI (Store.swift). Semua logic di sini
/// akan dipindah ke backend saat integrasi API; UI tidak berubah.
class MockStore extends ChangeNotifier {
  final List<Member> members = [];
  final List<Voucher> vouchers = [];
  final List<VoucherOwned> owned = [];
  final List<Ledger> ledgers = [];
  final List<Withdrawal> withdrawals = [];
  final List<Order> orders = [];
  List<MlmRule> rules = [];
  int downlineStep = 2;
  double multiplier = 0.5;
  String? currentId;

  MockStore() {
    _seed();
  }

  // ---------- seed (sama dengan demo Swift) ----------

  void _seed() {
    members.addAll([
      Member(id: 'admin', name: 'Administrator', email: 'admin@haji.local',
          role: 'admin', referralCode: 'ADMIN-HQ', balance: 0),
      Member(id: 'budi', name: 'Budi Santoso', email: 'budi@haji.local',
          role: 'buyer', referralCode: 'VCH-BUDI01', balance: 350000, downlines: 2),
      Member(id: 'andi', name: 'Andi Pratama', email: 'andi@haji.local',
          role: 'buyer', referralCode: 'VCH-ANDI88', parentId: 'budi',
          balance: 150000, downlines: 1),
      Member(id: 'citra', name: 'Citra Kirana', email: 'citra@haji.local',
          role: 'buyer', referralCode: 'VCH-CITRA99', parentId: 'andi', balance: 75000),
    ]);
    vouchers.addAll([
      Voucher(id: 'v1', title: 'Voucher Reguler 100K',
          price: 100000, value: 100000, isActive: true),
      Voucher(id: 'v2', title: 'Voucher Gold 500K',
          price: 500000, value: 525000, isActive: true),
      Voucher(id: 'v3', title: 'Voucher VIP 1 Juta',
          price: 1000000, value: 1100000, isActive: true),
    ]);
    rules = [
      MlmRule(level: 1, percentage: 5),
      MlmRule(level: 2, percentage: 3),
      MlmRule(level: 3, percentage: 1.5),
    ];
  }

  // ---------- helper ----------

  Member get current =>
      members.firstWhere((m) => m.id == currentId, orElse: () => members.first);

  List<Voucher> get activeVouchers => vouchers.where((v) => v.isActive).toList();

  List<Ledger> get userLedger => ledgers
      .where((l) => l.memberId == current.id)
      .toList()
      .reversed
      .toList();

  List<VoucherOwned> get userOwned =>
      owned.where((o) => o.memberId == current.id).toList().reversed.toList();

  List<Order> get userOrders =>
      orders.where((o) => o.memberId == current.id).toList().reversed.toList();

  List<Withdrawal> get userWithdrawals => withdrawals
      .where((w) => w.memberId == current.id)
      .toList()
      .reversed
      .toList();

  List<Member> get directDownlines =>
      members.where((m) => m.parentId == current.id).toList();

  double get factorPreview =>
      1 + (current.downlines / downlineStep).floor() * multiplier;

  String? get uplineName {
    final up = members.where((m) => m.id == current.parentId).toList();
    return up.isEmpty ? null : up.first.name;
  }

  String _randomId(int n) {
    const chars = 'ABCDEF0123456789';
    final r = Random();
    return List.generate(n, (_) => chars[r.nextInt(chars.length)]).join();
  }

  void _ubah(void Function() fn) {
    fn();
    notifyListeners();
  }

  // ---------- auth (dummy) ----------

  /// Login dummy: email harus ada di data demo, password apa pun diterima.
  Member login(String email, String password) {
    if (email.trim().isEmpty || password.isEmpty) {
      throw AppException('Isi email dan password');
    }
    final m = members.where(
        (m) => m.email.toLowerCase() == email.trim().toLowerCase());
    if (m.isEmpty) throw AppException('Email tidak ditemukan');
    _ubah(() => currentId = m.first.id);
    return m.first;
  }

  void register(String name, String email, String password, String referral) {
    final n = name.trim();
    final e = email.trim().toLowerCase();
    if (n.length < 3 || !e.contains('@') || !e.contains('.')) {
      throw AppException('Isi nama dan alamat email yang valid');
    }
    if (password.length < 8) {
      throw AppException('Password minimal 8 karakter');
    }
    if (members.any((m) => m.email.toLowerCase() == e)) {
      throw AppException('Email sudah digunakan');
    }
    String? parentId;
    final ref = referral.trim();
    if (ref.isNotEmpty) {
      final up = _cariKodeReferral(ref);
      if (up == null) throw AppException('Kode referral tidak ditemukan');
      parentId = up.id;
    }
    final member = Member(
      id: 'm-${_randomId(8)}',
      name: n,
      email: e,
      role: 'buyer',
      referralCode: 'VCH-${_randomId(8)}',
      parentId: parentId,
    );
    _ubah(() {
      members.add(member);
      currentId = member.id;
      if (parentId != null) _tambahDownlineAncestor(parentId);
    });
  }

  void logout() => _ubah(() => currentId = null);

  // ---------- referral ----------

  Member? _cariKodeReferral(String code) {
    final found = members.where((m) =>
        m.referralCode.toUpperCase() == code.trim().toUpperCase() &&
        m.role == 'buyer');
    return found.isEmpty ? null : found.first;
  }

  void bindReferral(String code) {
    if (current.parentId != null) throw AppException('Akun sudah memiliki upline');
    final parent = _cariKodeReferral(code);
    if (parent == null) throw AppException('Kode referral tidak ditemukan');
    if (parent.id == current.id) {
      throw AppException('Tidak dapat menggunakan kode sendiri');
    }
    // cegah jaringan melingkar
    String? cursor = parent.id;
    while (cursor != null) {
      if (cursor == current.id) {
        throw AppException('Referral akan membuat jaringan melingkar');
      }
      final next =
          members.where((m) => m.id == cursor).toList();
      cursor = next.isEmpty ? null : next.first.parentId;
    }
    _ubah(() {
      current.parentId = parent.id;
      _tambahDownlineAncestor(parent.id);
    });
  }

  void _tambahDownlineAncestor(String startId) {
    String? cursor = startId;
    final visited = <String>{};
    while (cursor != null && !visited.contains(cursor)) {
      visited.add(cursor);
      final m = members.where((m) => m.id == cursor).toList();
      if (m.isEmpty) break;
      m.first.downlines += 1;
      cursor = m.first.parentId;
    }
  }

  // ---------- order & pembayaran ----------

  Order createOrder(Voucher voucher, {String referral = ''}) {
    final live = vouchers.where((v) => v.id == voucher.id && v.isActive);
    if (live.isEmpty) throw AppException('Voucher tidak tersedia');
    if (current.parentId == null && referral.trim().isNotEmpty) {
      bindReferral(referral);
    }
    final order = Order(
      id: 'ORD-${_randomId(10)}',
      memberId: current.id,
      voucherId: live.first.id,
      amount: live.first.price,
      value: live.first.value,
      status: 'pending',
      createdAt: DateTime.now(),
    );
    _ubah(() => orders.add(order));
    return order;
  }

  /// Simulasi pembayaran Midtrans berhasil: kredit saldo + cashback MLM.
  /// Di produksi digantikan webhook settlement di backend.
  void payOrder(String orderId) {
    final order = orders.where((o) => o.id == orderId).toList();
    if (order.isEmpty) throw AppException('Order tidak ditemukan');
    if (order.first.status != 'pending') {
      throw AppException('Order sudah diproses');
    }
    final o = order.first;
    _ubah(() {
      o.status = 'settlement';
      final buyer = members.firstWhere((m) => m.id == o.memberId);
      buyer.balance += o.value;
      final vmatch = vouchers.where((v) => v.id == o.voucherId).toList();
      final title = vmatch.isEmpty ? 'Voucher' : vmatch.first.title;
      owned.add(VoucherOwned(
        id: 'ow-${_randomId(8)}',
        memberId: buyer.id,
        title: title,
        value: o.value,
        orderId: o.id,
        createdAt: DateTime.now(),
      ));
      _tambahLedger(buyer.id, 'topup', 'Top-Up $title', o.value, o.id);
      _bagikanCashback(buyer, o);
    });
  }

  void _bagikanCashback(Member buyer, Order o) {
    var cursor = buyer.parentId;
    final visited = {buyer.id};
    for (final rule in rules..sort((a, b) => a.level.compareTo(b.level))) {
      if (cursor == null || visited.contains(cursor)) break;
      final up = members.where((m) => m.id == cursor).toList();
      if (up.isEmpty) break;
      final upline = up.first;
      visited.add(upline.id);
      final steps =
          downlineStep > 0 ? upline.downlines ~/ downlineStep : 0;
      final factor = 1.0 + steps * multiplier;
      final payout = (o.amount * rule.percentage / 100 * factor).round();
      if (payout > 0) {
        upline.balance += payout;
        _tambahLedger(upline.id, 'mlm_cashback',
            'Cashback Level ${rule.level} ×${factor.toStringAsFixed(2)} dari ${buyer.name}',
            payout, o.id);
      }
      cursor = upline.parentId;
    }
  }

  void cancelOrder(String orderId) {
    final o = orders.where((o) => o.id == orderId && o.status == 'pending');
    if (o.isEmpty) throw AppException('Order tidak dapat dibatalkan');
    _ubah(() => o.first.status = 'cancel');
  }

  // ---------- withdraw ----------

  void requestWithdrawal(int amount, String bank, String account, String holder) {
    final b = bank.trim();
    final a = account.trim();
    final h = holder.trim();
    if (amount <= 0 || amount > current.balance) {
      throw AppException('Nominal tidak valid atau saldo tidak mencukupi');
    }
    if (b.isEmpty || a.length < 5 || h.isEmpty) {
      throw AppException('Lengkapi nama bank, rekening, dan pemilik rekening');
    }
    final id = 'WD-${_randomId(10)}';
    _ubah(() {
      current.balance -= amount;
      withdrawals.add(Withdrawal(
        id: id,
        memberId: current.id,
        amount: amount,
        bank: b,
        account: a,
        holder: h,
        status: 'pending',
        createdAt: DateTime.now(),
      ));
      _tambahLedger(current.id, 'withdraw', 'Hold withdraw ke $b', -amount, id);
    });
  }

  void _tambahLedger(
      String memberId, String type, String title, int amount, String orderId) {
    ledgers.add(Ledger(
      id: 'lg-${_randomId(8)}',
      memberId: memberId,
      type: type,
      title: title,
      amount: amount,
      orderId: orderId,
      createdAt: DateTime.now(),
    ));
  }
}
