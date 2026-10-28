# Flutter App Implementation Plan (VoucherUmrohHaji)

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Aplikasi Flutter produksi yang terintegrasi penuh dengan backend ASP.NET Core (`service`), dengan UI **disamakan persis** dengan aplikasi demo SwiftUI lama (`VoucherUmrohHaji/*.swift`).

**Architecture:** Riverpod untuk state, `dio` + interceptor auto-refresh token, `flutter_secure_storage` untuk token, Navigator bawaan (tanpa go_router — hanya login + shell tab). Semua logic uang di backend; app hanya render + request. Checkout membuka Snap URL Midtrans via `url_launcher`, lalu poll status order.

**Tech Stack:** Flutter (Material 3), flutter_riverpod, dio, flutter_secure_storage, intl, url_launcher, share_plus.

**Spec:** `docs/superpowers/specs/2026-10-27-voucher-production-design.md` · **Prasyarat:** plan backend (`2026-10-27-backend-service.md`) selesai dan API jalan di `http://10.0.2.2:<port>` (Android emulator) / `http://localhost:<port>` — baseURL dari `--dart-define=API_BASE_URL`.

## Global Constraints

- Bahasa UI: Indonesia, teks disalin dari string Swift (kecuali catatan per-layar di bawah).
- Ikuti CLAUDE.md (naming, ukuran file ≤300 baris).
- Commit Conventional Commits (`feat(flutter): ...`), tanpa co-author trailer, push `origin main` tiap task.
- Jangan commit `build/`, `.dart_tool/`.

## Design tokens (ekstrak persis dari Swift)

| Token | Nilai Swift | Nilai Flutter |
|---|---|---|
| Tint utama | `Color(red:0.07,green:0.48,blue:0.42)` | `Color(0xFF127A6B)` |
| Gradient BalanceCard awal | `(0.04,0.45,0.39)` | `Color(0xFF0A7363)` |
| Gradient BalanceCard akhir | `(0.03,0.29,0.32)` | `Color(0xFF084A52)` |
| Gradient arah | topLeft → bottomRight | `begin: topLeft, end: bottomRight` |
| Radius kartu besar / voucher | 20 / 16 | `BorderRadius.circular(20)` / `(16)` |
| Padding kartu | 24 / 16 | sama |
| Saldo besar | size 31, bold, rounded, scale 0.6 | `TextStyle(fontSize:31, fontWeight:w700)` + `maxScale` via `FittedBox` |
| Label kartu | subheadline, opacity 0.85, putih | `fontSize:13, color: Colors.white70` |
| Hijau saldo / merah | `.green` / `.red` | `Colors.green[700]!` / `Colors.red[700]!` |
| Status withdraw | approved=green, rejected=red, pending=orange | sama |
| Tema | tint teal | `ColorScheme.fromSeed(seedColor: Color(0xFF127A6B))` |

Format Rupiah (ganti extension `Int.rupiah` Swift): `NumberFormat.currency(locale:'id_ID', symbol:'Rp', decimalDigits:0)` di `core/rupiah.dart` → `int.rupiah`. Format tanggal `shortID` → `DateFormat('d MMM yyyy HH:mm', 'id_ID')` di `core/tanggal.dart`.

## Bentuk respons API (dipakai semua task — backend wajib sama)

```jsonc
// POST /api/auth/register | login | refresh → 200
{ "accessToken": "...", "refreshToken": "...", "expiresIn": 900,
  "member": { "id","name","email","role","referralCode","balance","downlines","parentId" } }
// GET /api/vouchers → [{ "id","title","price","value","isActive" }] (aktif saja)
// POST /api/orders {voucherId} → { "orderId","amount","value","status","snapToken","snapUrl" }
// GET /api/orders → [{ "orderId","voucherTitle","amount","value","status","createdAt" }] terbaru dulu
// GET /api/wallet → { "balance", "owned":[{"title","value","orderId","createdAt"}],
//                      "ledger":[{"type","title","amount","orderId","createdAt"}] }
// GET /api/referral/me → { "referralCode","downlines","directDownlines":[{"name"}],
//                           "factorPreview","uplineName","rules":[{"level","percentage"}] }
// POST /api/referral/bind {referralCode} → 200
// POST /api/withdrawals {amount,bank,account,holder} → 200
// GET /api/withdrawals → [{ "id","amount","bank","account","holder","status","createdAt" }]
// GET /api/admin/withdrawals → sama, semua user
// POST /api/admin/withdrawals/{id}/approve | reject → 200
// GET /api/admin/vouchers → semua voucher (termasuk nonaktif)
// POST /api/admin/vouchers {title,price,value} · PUT {title,price,value,isActive} · DELETE
// GET /api/admin/members?page → { "items":[MemberDto + email], "totalPages" }
// PUT /api/admin/mlm-config {levels[], downlineStep, multiplier}
```
Semua error: `{ "error": "pesan" }` → tampilkan `pesan` via SnackBar.

## Struktur file

```
VoucherUmrohHaji/mobile/lib/
├── main.dart                    # ProviderScope + MaterialApp + router root
├── core/
│   ├── api_client.dart          # dio + interceptor refresh + attach token
│   ├── token_storage.dart       # secure storage: access/refresh/member
│   ├── rupiah.dart, tanggal.dart
│   └── widgets/balance_card.dart
├── providers/
│   ├── auth_provider.dart       # member saat ini, login/register/logout
│   └── data_providers.dart      # vouchers, wallet, referral, withdrawals, orders (FutureProvider family + refresh)
└── features/
    ├── auth/login_screen.dart, register_screen.dart
    ├── buyer/buyer_shell.dart   # Scaffold + NavigationBar 4 tab
    ├── buyer/shop_screen.dart, checkout_sheet.dart
    ├── buyer/wallet_screen.dart
    ├── buyer/referral_screen.dart
    ├── buyer/withdraw_screen.dart
    └── admin/admin_shell.dart, vouchers_screen.dart, voucher_editor_sheet.dart,
        mlm_config_screen.dart, approvals_screen.dart, members_screen.dart
```

---

### Task 1: Scaffold + core + tema

**Files:** pakai scaffold yang sudah ada di `VoucherUmrohHaji/mobile/` (JANGAN `flutter create` lagi): `pubspec.yaml`, `lib/main.dart`, `lib/core/api_client.dart`, `lib/core/token_storage.dart`, `lib/core/rupiah.dart`, `lib/core/tanggal.dart`, `lib/core/widgets/balance_card.dart`

- [ ] **Step 1:** Dalam `VoucherUmrohHaji/mobile/` tambahkan deps: `flutter_riverpod`, `dio`, `flutter_secure_storage`, `intl`, `url_launcher`, `share_plus` (`flutter pub add ...`).
- [ ] **Step 2:** `main.dart` — `ProviderScope`, `MaterialApp(theme: ThemeData(colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF127A6B)), useMaterial3: true))`, home = placeholder autentikasi (Task 2).
- [ ] **Step 3:** `api_client.dart` — dio `baseUrl = const String.fromEnvironment('API_BASE_URL', defaultValue: 'http://10.0.2.2:5080')`, interceptor: taruh `Authorization: Bearer <access>`; saat 401 → sekali `POST /api/auth/refresh` (lock agar tidak storm), simpan token baru, retry request; gagal → bersihkan storage + navigasi ke login.
- [ ] **Step 4:** `BalanceCard` widget — Container gradient `0xFF0A7363 → 0xFF084A52` topLeft→bottomRight, radius 20, padding 24, kolom kiri: label (icon wallet + teks, putih 70%) + saldo `fontSize 31 bold` putih, `FittedBox` alignment kiri. API: `BalanceCard({required String title, required int amount})`.
- [ ] **Step 5:** Widget test kecil: `BalanceCard` render "Rp 100.000" (pakai `rupiah`). `flutter analyze` + `flutter test` hijau.
- [ ] **Step 6:** Commit `feat(flutter): scaffold app, tema teal, api client, balance card` + push.

### Task 2: Auth — Login & Register

**Files:** `providers/auth_provider.dart`, `features/auth/login_screen.dart`, `features/auth/register_screen.dart`, edit `main.dart`

- [ ] **Step 1:** `auth_provider.dart` — `StateNotifierProvider<AuthController, AsyncValue<Member?>>`; `login(email,password)`, `register(name,email,password,referral)` (POST sesuai bentuk API, simpan `AuthResponse` ke storage), `logout()` (hapus storage). Saat start: baca storage → ada member → langsung shell.
- [ ] **Step 2:** **LoginScreen** — judul app "Voucher Umroh & Haji", fields Email + Password, tombol "Masuk" filled, teks bawah "Belum punya akun? Daftar" → RegisterScreen. Error → SnackBar pesan `error`.
- [ ] **Step 3:** **RegisterScreen** — Form seperti `RegisterSheet` Swift: "Buyer Baru", fields Nama lengkap / Email / **Password** (baru, tidak ada di Swift karena produksi) / Kode referral (opsional). Tombol "Daftar & Masuk". Caption: "Pendaftaran dengan password — data disimpan aman di server."
- [ ] **Step 4:** Setelah login: role `admin` → AdminShell, `buyer` → BuyerShell (Navigator.pushReplacement). NavigationBar/BottomNavigationBar sesuai role.
- [ ] **Step 5:** Widget test: form register validasi kosong → tidak submit; error API → SnackBar. `flutter test` hijau.
- [ ] **Step 6:** Commit `feat(flutter): login, register, sesi token, redirect per role` + push.

### Task 3: Buyer shell + Top-Up (Shop) + Checkout Snap

**Files:** `features/buyer/buyer_shell.dart`, `shop_screen.dart`, `checkout_sheet.dart`, `providers/data_providers.dart`

- [ ] **Step 1:** **BuyerShell** — AppBar title "Voucher Umroh & Haji" (centerTitle, `titleTextStyle` ukuran default), aksi kanan: PopupMenu (nama member + "Keluar" → logout). NavigationBar 4 destinasi persis Swift: Top-Up (icon `shopping_bag`) / Dompet (`account_balance_wallet`) / Referal (`group`) / Withdraw (`outbound`).
- [ ] **Step 2:** **ShopScreen** — scroll: `BalanceCard("Saldo aktif", member.balance)` → caption "Saldo dan cashback dikreditkan otomatis setelah pembayaran Midtrans berhasil." → judul "Paket Voucher" (titleLarge bold) + subteks "Pilih voucher untuk membeli dan membayar via Midtrans." → daftar `VoucherCard`: Container surface (`cardTheme`), radius 16: baris judul (icon `card_giftcard` + title headline), "Harga bayar …… Rp" bold, "Saldo diterima …… Rp" hijau bold, tombol "Beli Voucher" filled lebar penuh rata kanan. Data: `GET /api/vouchers` FutureProvider + `RefreshIndicator`.
- [ ] **Step 3:** **CheckoutSheet** (modal bottom sheet, tinggi ~85%) — section "Detail Checkout": LabeledRow Voucher / Tagihan / Saldo diterima. Bila `parentId == null`: field "Kode referral (opsional)". Tombol "Buat Order" → **jika referral diisi: `POST /api/referral/bind` DULU** (gagal → SnackBar, jangan lanjut), baru `POST /api/orders {"voucherId"}` → tampil "Nomor ORD-…", "Status Pending", tombol hijau **"Bayar dengan Midtrans"** → `launchUrl(snapUrl, mode: externalApplication)`; tombol merah "Batalkan Order" → `POST cancel`. Caption bawah: "Pembayaran diproses Midtrans. Status order diperbarui otomatis dari server."
- [ ] **Step 4:** Setelah kembali dari Midtrans: poll `GET /api/orders/{id}/status` tiap 3 detik maksimal 10x → status `settlement` → refresh wallet+shop, tampil sukses "Pembayaran berhasil, saldo masuk" (hijau) + tutup sheet; `expire/cancel` → info. (Backend path status: `GET /api/orders/{id}/status` — gunakan itu, bukan `/api/orders`.)
- [ ] **Step 5:** Widget test: VoucherCard menampilkan harga & nilai; CheckoutSheet menampilkan referral field saat parentId null. `flutter test` + `flutter analyze` hijau.
- [ ] **Step 6:** Commit `feat(flutter): tab buyer, katalog voucher, checkout dengan Midtrans Snap` + push.

### Task 4: Dompet (Wallet)

**Files:** `features/buyer/wallet_screen.dart`

- [ ] **Step 1:** Layout List sesuai `WalletView` Swift: (1) `BalanceCard("Dompet Saya", balance)`; (2) section "Inventory Voucher (n)" — baris: judul bold kiri + `+Rp` hijau kanan; caption `orderId • tanggal`; kosong → "Belum ada voucher" abu; (3) "Mutasi Saldo" — leading icon lingkaran fill panah (masuk hijau `arrow_downward`/keluar merah `arrow_upward`), title subteks bold, caption tanggal, trailing `±Rp` berwarna; kosong → "Belum ada mutasi"; (4) "Pesanan" — caption `orderId` kiri + status bold kanan (capitalize). Data `GET /api/wallet` + refresh.
- [ ] **Step 2:** Widget test: render ledger +/- berwarna benar. Commit `feat(flutter): dompet — saldo, inventory, mutasi, pesanan` + push.

### Task 5: Referal

**Files:** `features/buyer/referral_screen.dart`

- [ ] **Step 1:** Section "Kode Referral Saya": teks besar monospace bold (selectable) + tombol "Bagikan Kode" (icon share) → `Share.share('Gunakan kode referral saya: $code')`.
- [ ] **Step 2:** Section "Jaringan": rows "Total Downline — n anggota", "Downline Langsung — n", "Pengali Cashback — 1.50x" (`factorPreview.toStringAsFixed(2) + 'x'`), daftar nama downline langsung (icon `person`).
- [ ] **Step 3:** `uplineName == null` → section "Hubungkan Upline": TextField kode + tombol "Hubungkan Referral" (`POST /api/referral/bind`, sukses → refresh + SnackBar); selain itu → row hijau icon `verified` "Akun terhubung dengan upline".
- [ ] **Step 4:** Section "Persentase MLM": rows "Level n — x.xx%" + caption rumus "Cashback = Harga Bayar × Persentase Level × (1 + ⌊Total Downline / Step⌋ × Faktor)".
- [ ] **Step 5:** Widget test bind sukses/gagal. Commit `feat(flutter): layar referal — kode, jaringan, bind upline, tabel komisi` + push.

### Task 6: Withdraw (Buyer)

**Files:** `features/buyer/withdraw_screen.dart`

- [ ] **Step 1:** Form sesuai `WithdrawView`: `BalanceCard("Saldo Tersedia")`; section "Ajukan Withdraw": fields Nominal (Rp, angka) / Nama bank / e-wallet / Nomor rekening / Nama pemilik rekening; tombol filled "Ajukan Penarikan" (`POST /api/withdrawals`); sukses → kosongkan form + refresh.
- [ ] **Step 2:** Section "Status Penarikan": baris jumlah bold + status kanan berwarna (approved hijau / rejected merah / pending oranye), caption `bank • account • tanggal`; kosong → "Belum ada permintaan penarikan". Caption bawah: "Permintaan menahan saldo hingga admin menyetujui atau menolak."
- [ ] **Step 3:** Widget test validasi (nominal kosong/0 tidak submit). Commit `feat(flutter): pengajuan withdraw dan status` + push.

### Task 7: Admin — Shell, Voucher CRUD, Editor

**Files:** `features/admin/admin_shell.dart`, `vouchers_screen.dart`, `voucher_editor_sheet.dart`

- [ ] **Step 1:** **AdminShell** — AppBar "Panel Admin", PopupMenu logout, NavigationBar 4 tab: Voucher (`card_giftcard`) / Komisi (`hub`) / Approval (`verified_user`) / Anggota (`group`).
- [ ] **Step 2:** **VouchersScreen** — tombol atas "Tambah Voucher"; daftar semua voucher (termasuk nonaktif, `GET /api/admin/vouchers`): judul headline + badge kanan "Aktif" hijau / "Nonaktif" abu; rows Harga / Saldo (`labeledRow`); deretan tombol Outlined: "Edit" → editor sheet, "Nonaktifkan"/"Aktifkan" → PUT toggle, "Hapus" merah → DELETE (409 "pernah ditransaksikan" → SnackBar pesan itu).
- [ ] **Step 3:** **VoucherEditorSheet** — Form: Nama paket / Harga bayar (angka) / Nilai saldo diterima (angka) / SwitchTile "Aktif"; judul "Voucher Baru" atau "Edit Voucher"; tombol "Simpan Voucher" (POST/PUT). Validasi angka > 0 sebelum submit.
- [ ] **Step 4:** Widget test editor validasi. Commit `feat(flutter): admin voucher CRUD dan editor` + push.

### Task 8: Admin — Komisi, Approval, Anggota

**Files:** `features/admin/mlm_config_screen.dart`, `approvals_screen.dart`, `members_screen.dart`

- [ ] **Step 1:** **MlmConfigScreen** (`MLMSettingsView`) — section "Persentase Cashback per Level": tiap level row "Level n" + field % (desimal, koma didukung) + tombol "Tambah Level" / "Hapus Level Terakhir" (1–20); section "Bonus Multiplier": field "Kelipatan jumlah downline" + "Tambahan faktor per kelipatan" + caption contoh "2 downline dengan faktor 0.5 menghasilkan pengali 1.5×."; tombol "Simpan Konfigurasi" (`PUT /api/admin/mlm-config`). Prefill dari `GET /api/referral/me` (rules+step+factor — bila backend menyatukan di endpoint admin, gunakan itu).
- [ ] **Step 2:** **ApprovalsScreen** (`AdminWithdrawView`) — section "Menunggu Approval • n": card per pending: nama user bold, jumlah titleLarge bold, caption `bank • account • holder`, caption kecil `id • tanggal • status`; tombol "Tolak" (outlined merah) + "Setujui (sudah transfer)" (filled). Section "Riwayat Approval" tanpa tombol. Caption: "Pastikan dana telah ditransfer secara terpisah sebelum menyetujui."
- [ ] **Step 3:** **MembersScreen** (`AdminMembersView`) — section "Ringkasan": Total pengguna / Buyer / Total Order; section "Pengguna dan Jaringan": card per member: nama bold + role caption kanan, email caption, rows Saldo / Kode / Downline, caption "Upline: <nama>" bila ada. Pagination "Muat lagi" per 20.
- [ ] **Step 4:** `flutter analyze` 0 issue, `flutter test` hijau, `flutter build apk --debug` sukses. Commit `feat(flutter): admin komisi, approval withdraw, daftar anggota` + push.

### Task 9: Verifikasi integrasi end-to-end

- [ ] **Step 1:** Backend run lokal + `flutter run --dart-define=API_BASE_URL=http://10.0.2.2:5080`. Uji manual alur penuh: register (pakai referral) → beli voucher → bayar di Snap **sandbox** → saldo masuk → downline dapat cashback → withdraw → admin approve. Screenshot tiap layar untuk bukti.
- [ ] **Step 2:** Perbaiki temuan, commit `fix(flutter): ...` bila ada, push. Update README root bagian Flutter (cara run, dart-define, sandbox).

## Catatan perbedaan disengaja dari Swift (produksi)
- Ganti menu "ganti akun demo" → login/logout sungguhan; "Reset data demo" dihapus.
- Tombol "Simulasikan Pembayaran Berhasil" → "Bayar dengan Midtrans" (URL Snap asli).
- Register menambah field Password; caption mode-demo diganti teks produksi.
- Semua caption "MODE DEMO / bukan uang nyata" dihapus.
