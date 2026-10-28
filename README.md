# haji

Voucher top-up Umroh & Haji dengan cashback dan point

## Endpoint

| Method | Path | Keterangan |
|---|---|---|
| POST | `/api/auth/register` | Daftar (nama, email, password, referral opsional) |
| POST | `/api/auth/login` | Login, dapat access + refresh token |
| POST | `/api/auth/refresh` | Tukar refresh token |
| GET | `/api/vouchers` | Daftar voucher aktif |
| POST | `/api/orders` | Buat order, dapat Snap token/url Midtrans |
| GET | `/api/orders` | Riwayat order milik sendiri |
| POST | `/api/orders/{id}/cancel` | Batalkan order pending |
| GET | `/api/orders/{id}/status` | Cek status order (+ inquiry Midtrans) |
| POST | `/api/webhooks/midtrans` | Notifikasi pembayaran (verifikasi signature) |
| GET | `/api/wallet` | Saldo, voucher dimiliki, mutasi |
| GET | `/api/referral/me` | Kode referral, jaringan, pengali cashback |
| POST | `/api/referral/bind` | Hubungkan upline |
| POST | `/api/withdrawals` | Ajukan penarikan (saldo di-hold) |
| GET | `/api/withdrawals` | Riwayat penarikan |
| GET/POST/PUT/DELETE | `/api/admin/vouchers` (PUT/DELETE `/{id}`) | CRUD voucher (admin); GET mengembalikan semua voucher termasuk nonaktif (katalog buyer: `GET /api/vouchers`, aktif saja) |
| GET | `/api/admin/withdrawals` | Semua pengajuan withdraw (admin) |
| POST | `/api/admin/withdrawals/{id}/approve` / `reject` | Approval withdraw (admin) |
| GET | `/api/admin/members` | Daftar anggota (admin) |
| PUT | `/api/admin/mlm-config` | Persentase per level, step, multiplier (admin) |
| GET | `/api/health` | Health check |

Autentikasi: JWT Bearer (`Authorization: Bearer <token>`). Endpoint admin butuh role `admin`. Webhook Midtrans anonim (diverifikasi via signature SHA512).

## Menjalankan (dev)

### Cara 1 — Docker (Postgres + API sekaligus, direkomendasikan)

```bash
# 1. Siapkan .env dari contoh, lalu edit isinya
copy .env.example .env        # Windows   (Linux/macOS: cp)

# 2. Nyalakan Postgres + API (build pertama ~1-2 menit)
docker compose up --build -d

# 3. Cek sehat
curl http://localhost:5038/api/health     # → {"status":"ok"}

# Hentikan / bersihkan
docker compose down          # data Postgres tetap (volume pgdata)
```

Login admin hasil seed: `admin@haji.local` + `ADMIN_PASSWORD` dari `.env` Anda.

Variabel `.env` (lengkap di `.env.example`): `JWT_KEY` *(wajib, ≥32 karakter acak)* · `ADMIN_PASSWORD` *(wajib)* · `MIDTRANS_SERVER_KEY` *(sandbox `SB-Mid-server-...`, kosong = order ditolak "Layanan pembayaran sedang tidak tersedia")* · `JWT_ISSUER`/`JWT_AUDIENCE`/`API_PORT` *(opsional, ada default)*.

### Cara 2 — Tanpa Docker

```bash
docker run -d --name haji-pg -e POSTGRES_PASSWORD=haji -e POSTGRES_DB=voucher -p 5432:5432 postgres:16
cd VoucherUmrohHaji/service
dotnet user-secrets init
dotnet user-secrets set "AdminUser:Password" "<password-admin>"   # wajib, untuk seed akun admin
dotnet user-secrets set "Jwt:Key" "<minimal-32-karakter>"         # wajib
dotnet user-secrets set "Midtrans:ServerKey" "<server-key>"
dotnet run   # API di http://localhost:5038 (sesuai launchSettings.json)
```

### Web admin (daisyUI)

```bash
cd web && npm install && npm run dev   # → http://localhost:5173 (proxy /api ke 5038)
```

### Flutter (manual)

```bash
cd VoucherUmrohHaji/mobile
flutter pub get
# Atur API_BASE_URL di file .env proyek mobile:
#   - Android emulator : http://10.0.2.2:5038
#   - Device fisik     : http://<IP-LAN-komputer>:5038  (firewall: izinkan port 5038)
flutter run
```

Dokumen OpenAPI tersedia di `/openapi/v1.json` (hanya environment Development).

Webhook Midtrans: di dashboard Midtrans (Settings → Configuration), set Payment Notification URL ke `https://<host-public>/api/webhooks/midtrans`. Untuk dev lokal pakai ngrok/dev tunnel karena Midtrans harus bisa menjangkau mesinmu.

### Batasan diketahui (backend, v1)

- Settlement tidak membandingkan `gross_amount` dari Midtrans dengan nominal order — nilai order sendiri yang dipakai.
- Notifikasi `refund` / `partial_refund` dari Midtrans saat ini diabaikan (no-op), saldo tidak berkurang.
