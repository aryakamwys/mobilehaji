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

Backend ada di `VoucherUmrohHaji/service` (.NET Minimal API). Butuh Postgres.

```bash
# Postgres (samakan dengan ConnectionStrings:Default di appsettings.Development.json)
docker run -d --name haji-pg -e POSTGRES_PASSWORD=haji -e POSTGRES_DB=voucher -p 5432:5432 postgres:16

cd VoucherUmrohHaji/service
dotnet user-secrets init
dotnet user-secrets set "AdminUser:Password" "<password-admin>"   # wajib, untuk seed akun admin
dotnet user-secrets set "Jwt:Key" "<minimal-32-karakter>"         # wajib
dotnet user-secrets set "Midtrans:ServerKey" "<server-key>"
dotnet run   # API di http://localhost:5038 (sesuai launchSettings.json)
```

Dokumen OpenAPI tersedia di `/openapi/v1.json` (hanya environment Development).

Webhook Midtrans: di dashboard Midtrans (Settings → Configuration), set Payment Notification URL ke `https://<host-public>/api/webhooks/midtrans`. Untuk dev lokal pakai ngrok/dev tunnel karena Midtrans harus bisa menjangkau mesinmu.
