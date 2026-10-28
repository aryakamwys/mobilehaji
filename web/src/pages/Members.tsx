import { useEffect, useState } from 'react'
import { listMembers, type MembersPage } from '../api/members'
import { rupiah } from '../lib/format'

export default function Members() {
  const [page, setPage] = useState(1)
  const [data, setData] = useState<MembersPage>({ items: [], totalPages: 1 })
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState('')

  async function load(p: number) {
    setLoading(true)
    setError('')
    try {
      setData(await listMembers(p))
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Gagal memuat anggota')
    } finally {
      setLoading(false)
    }
  }

  useEffect(() => {
    void load(page)
  }, [page])

  return (
    <div className="space-y-4">
      <div className="flex items-center justify-between">
        <h1 className="text-2xl font-bold">Anggota</h1>
        <button className="btn btn-ghost btn-sm" onClick={() => void load(page)} disabled={loading}>
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
          <div className="overflow-x-auto">
            <table className="table">
              <thead>
                <tr>
                  <th>Nama</th>
                  <th>Email</th>
                  <th>Role</th>
                  <th>Kode Referral</th>
                  <th>Saldo</th>
                  <th>Downline</th>
                </tr>
              </thead>
              <tbody>
                {data.items.map((m) => (
                  <tr key={m.id}>
                    <td className="font-medium">{m.name}</td>
                    <td>{m.email}</td>
                    <td>
                      <span className={`badge ${m.role === 'admin' ? 'badge-neutral' : 'badge-ghost'}`}>
                        {m.role}
                      </span>
                    </td>
                    <td>{m.referralCode}</td>
                    <td>{rupiah(m.balance)}</td>
                    <td>{m.downlines}</td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>

          <div className="join">
            <button
              className="btn join-item"
              disabled={page <= 1}
              onClick={() => setPage((p) => p - 1)}
            >
              « Prev
            </button>
            {Array.from({ length: data.totalPages }, (_, i) => (
              <button
                key={i}
                className={`btn join-item ${page === i + 1 ? 'btn-primary' : ''}`}
                onClick={() => setPage(i + 1)}
              >
                {i + 1}
              </button>
            ))}
            <button
              className="btn join-item"
              disabled={page >= data.totalPages}
              onClick={() => setPage((p) => p + 1)}
            >
              Next »
            </button>
          </div>
        </>
      )}
    </div>
  )
}
