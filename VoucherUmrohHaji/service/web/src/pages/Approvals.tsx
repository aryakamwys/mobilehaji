import { useEffect, useState } from 'react'
import {
  approveWithdrawal,
  listWithdrawals,
  rejectWithdrawal,
  type Withdrawal,
} from '../api/withdrawals'
import { rupiah, tanggal } from '../lib/format'

export default function Approvals() {
  const [items, setItems] = useState<Withdrawal[]>([])
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState('')
  const [busyId, setBusyId] = useState<number | null>(null)
  const [toast, setToast] = useState('')

  const pending = items.filter((w) => w.status === 'pending')
  const history = items.filter((w) => w.status !== 'pending')

  async function load() {
    setLoading(true)
    setError('')
    try {
      setItems(await listWithdrawals())
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Gagal memuat penarikan')
    } finally {
      setLoading(false)
    }
  }

  useEffect(() => {
    void load()
  }, [])

  useEffect(() => {
    if (!toast) return
    const t = setTimeout(() => setToast(''), 3000)
    return () => clearTimeout(t)
  }, [toast])

  async function act(w: Withdrawal, action: 'approve' | 'reject') {
    setBusyId(w.id)
    setError('')
    try {
      if (action === 'approve') await approveWithdrawal(w.id)
      else await rejectWithdrawal(w.id)
      setToast(action === 'approve' ? 'Penarikan disetujui.' : 'Penarikan ditolak, saldo dikembalikan.')
      await load()
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Gagal memproses penarikan')
      await load()
    } finally {
      setBusyId(null)
    }
  }

  return (
    <div className="space-y-6">
      <div className="flex items-center justify-between">
        <h1 className="text-2xl font-bold">Approval Penarikan</h1>
        <button className="btn btn-ghost btn-sm" onClick={() => void load()} disabled={loading}>
          Muat Ulang
        </button>
      </div>

      {error && (
        <div role="alert" className="alert alert-error">
          {error}
        </div>
      )}

      {loading ? (
        <div className="flex justify-center py-12">
          <span className="loading loading-spinner loading-lg" />
        </div>
      ) : (
        <>
          <section className="space-y-3">
            <h2 className="text-lg font-semibold">
              Menunggu Approval{' '}
              <span className="badge badge-warning badge-soft">• {pending.length}</span>
            </h2>
            {pending.length === 0 ? (
              <div className="alert">Tidak ada penarikan yang menunggu approval.</div>
            ) : (
              <div className="grid gap-3 md:grid-cols-2 xl:grid-cols-3">
                {pending.map((w) => (
                  <div key={w.id} className="card bg-base-100 card-border">
                    <div className="card-body">
                      <div className="text-3xl font-bold text-primary">{rupiah(w.amount)}</div>
                      <div>
                        {w.bank} • {w.account} • {w.holder}
                      </div>
                      <div className="text-sm opacity-60">
                        #{w.id} • {tanggal(w.createdAt)}
                      </div>
                      <div className="card-actions justify-end">
                        <button
                          className="btn btn-outline btn-error"
                          disabled={busyId === w.id}
                          onClick={() => void act(w, 'reject')}
                        >
                          Tolak
                        </button>
                        <button
                          className="btn btn-primary"
                          disabled={busyId === w.id}
                          onClick={() => void act(w, 'approve')}
                        >
                          {busyId === w.id && <span className="loading loading-spinner loading-sm" />}
                          Setujui
                        </button>
                      </div>
                    </div>
                  </div>
                ))}
              </div>
            )}
          </section>

          <section className="space-y-3">
            <h2 className="text-lg font-semibold">Riwayat</h2>
            {history.length === 0 ? (
              <div className="alert">Belum ada riwayat penarikan.</div>
            ) : (
              <div className="overflow-x-auto">
                <table className="table table-sm">
                  <thead>
                    <tr>
                      <th>Jumlah</th>
                      <th>Bank</th>
                      <th>Rekening</th>
                      <th>Pemilik</th>
                      <th>Tanggal</th>
                      <th>Status</th>
                    </tr>
                  </thead>
                  <tbody>
                    {history.map((w) => (
                      <tr key={w.id}>
                        <td className="font-medium">{rupiah(w.amount)}</td>
                        <td>{w.bank}</td>
                        <td>{w.account}</td>
                        <td>{w.holder}</td>
                        <td>{tanggal(w.createdAt)}</td>
                        <td>
                          <span className={`badge ${w.status === 'approved' ? 'badge-success' : 'badge-error'}`}>
                            {w.status === 'approved' ? 'Disetujui' : 'Ditolak'}
                          </span>
                        </td>
                      </tr>
                    ))}
                  </tbody>
                </table>
              </div>
            )}
          </section>
        </>
      )}

      {toast && (
        <div className="toast toast-end toast-bottom z-50">
          <div className="alert alert-success">{toast}</div>
        </div>
      )}
    </div>
  )
}
