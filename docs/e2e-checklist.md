# Checklist Uji End-to-End (E2E) — Aplikasi Flutter

Uji manual alur penuh aplikasi terhadap backend Docker.

## Persiapan

```bash
# 1. Jalankan backend (dari root repo)
cd VoucherUmrohHaji/service
docker compose up --build -d
# API: http://localhost:5038

# 2. Konfigurasi mobile (VoucherUmrohHaji/mobile/.env)
API_BASE_URL=http://10.0.2.2:5038   # Android emulator

# 3. Jalankan aplikasi
cd VoucherUmrohHaji/mobile
flutter run
```

Admin web (opsional): `cd web && npm run dev` → http://localhost:5173

> **Catatan Midtrans:** butuh `MIDTRANS_SERVER_KEY` sandbox terisi di environment
> service untuk membuat Snap token. Jika kosong, order ditolak dengan pesan
> "Layanan pembayaran sedang tidak tersedia" — tandai langkah pembayaran SKIP.

> **Catatan webhook lokal:** sandbox Midtrans hanya bisa mengirim webhook ke URL
> publik. Tanpa ngrok/dev tunnel, settlement tetap masuk lewat **inquiry
> otomatis** saat aplikasi mengecek status order (tombol Bayar mem-poll
> `/api/orders/{id}/status` yang memicu inquiry ke Midtrans).

## 1. Kesehatan Backend

- [ ] `GET http://localhost:5038/api/health` balas `ok`

## 2. Registrasi & Login Buyer

- [ ] Register buyer A **tanpa** kode referral → otomatis masuk, 4 tab buyer
      tampil (Belanja, Dompet, Referal, Profil)
- [ ] Register buyer B **pakai kode referral A** → masuk; layar Referal B
      menampilkan `uplineName` = nama A
- [ ] Login ulang sebagai A → jumlah jaringan (downline) A bertambah 1
- [ ] Logout → login ulang buyer → sesi normal

## 3. Admin

- [ ] Login admin (web localhost:5173 ATAU akun admin di Flutter) → Panel
      Admin tampil dengan 4 tab (Voucher, Konfigurasi, Approval, Anggota)
- [ ] Tambah voucher baru → muncul di katalog buyer
- [ ] Edit voucher (judul/harga/nilai) → perubahan tercermin di katalog buyer
- [ ] Nonaktifkan voucher → hilang dari katalog buyer; aktifkan lagi → muncul
- [ ] Hapus voucher yang **pernah diorder** → ditolak 409 dengan pesan error
- [ ] Ubah konfigurasi MLM (mis. level 1 = 10%) → simpan sukses, layar Referal
      buyer memperlihatkan aturan baru

## 4. Pembelian & Pembayaran (Midtrans Snap sandbox)

> SKIP semua sub-langkah di bawah jika `MIDTRANS_SERVER_KEY` kosong —
> verifikasi order ditolak dengan pesan "Layanan pembayaran sedang tidak
> tersedia".

- [ ] Buyer B membeli voucher → order berstatus **pending** + tombol
      "Bayar dengan Midtrans" muncul
- [ ] Tekan Bayar → Snap sandbox terbuka di browser/eksternal → selesaikan
      pembayaran
- [ ] Kembali ke app → status berubah **settlement** (poll/inquiry, atau
      instan via webhook ngrok)
- [ ] Saldo masuk ke Dompet B + voucher tampil di inventory
- [ ] Mutasi `topup` tampil di riwayat Dompet B
- [ ] Buyer A (upline) menerima cashback sesuai konfigurasi — cek Dompet A +
      mutasi `mlm_cashback`

## 5. Withdraw & Approval

- [ ] Buyer mengajukan withdraw → saldo Dompet berkurang (hold), mutasi
      `withdraw` negatif tampil
- [ ] Admin tab Approval: **Tolak** → saldo kembali ke buyer, mutasi `refund`
      tampil
- [ ] Buyer mengajukan withdraw lagi → Admin **Setujui** → status pengajuan
      jadi `approved`, saldo tidak kembali

## 6. Anggota & Sesi

- [ ] Admin tab Anggota: daftar member tampil, pagination prev/next berfungsi
- [ ] Logout → login ulang sebagai buyer DAN admin → keduanya normal
- [ ] Refresh token: biarkan app idle > 15 menit (access token kedaluwarsa),
      lalu lakukan aksi apa pun → request tetap lanjut tanpa dipaksa logout
      (auto-refresh bekerja)
