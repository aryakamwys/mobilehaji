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
| GET/POST/PUT/DELETE | `/api/admin/vouchers` | CRUD voucher (admin) |
| GET | `/api/admin/withdrawals` | Semua pengajuan withdraw (admin) |
| POST | `/api/admin/withdrawals/{id}/approve` / `reject` | Approval withdraw (admin) |
| GET | `/api/admin/members` | Daftar anggota (admin) |
| PUT | `/api/admin/mlm-config` | Persentase per level, step, multiplier (admin) |
| GET | `/api/health` | Health check |

Autentikasi: JWT Bearer (`Authorization: Bearer <token>`). Endpoint admin butuh role `admin`.

## Menjalankan (dev)

ntar dibikin
