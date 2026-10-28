import { useEffect, useRef, useState, type FormEvent } from 'react'
import { createVoucher, deleteVoucher, listVouchers, updateVoucher, type Voucher } from '../api/vouchers'
import { rupiah } from '../lib/format'

export default function Vouchers() {
  const [items, setItems] = useState<Voucher[]>([])
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState('')
  const formDlg = useRef<HTMLDialogElement>(null)
  const delDlg = useRef<HTMLDialogElement>(null)
  const [editing, setEditing] = useState<Voucher | null>(null)
  const [title, setTitle] = useState('')
  const [price, setPrice] = useState('')
  const [value, setValue] = useState('')
  const [isActive, setIsActive] = useState(true)
  const [formError, setFormError] = useState('')
  const [delTarget, setDelTarget] = useState<Voucher | null>(null)
  const [delError, setDelError] = useState('')
  const [busy, setBusy] = useState(false)

  async function load() {
    setLoading(true)
    setError('')
    try {
      setItems(await listVouchers())
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Gagal memuat voucher')
    } finally {
      setLoading(false)
    }
  }

  useEffect(() => {
    void load()
  }, [])

  function openForm(v?: Voucher) {
    setFormError('')
    setEditing(v ?? null)
    setTitle(v?.title ?? '')
    setPrice(String(v?.price ?? ''))
    setValue(String(v?.value ?? ''))
    setIsActive(v?.isActive ?? true)
    formDlg.current?.showModal()
  }

  async function save(e: FormEvent) {
    e.preventDefault()
    setBusy(true)
    setFormError('')
    try {
      if (editing) {
        await updateVoucher(editing.id, {
          title,
          price: Number(price),
          value: Number(value),
          isActive,
        })
      } else {
        await createVoucher({ title, price: Number(price), value: Number(value) })
      }
      formDlg.current?.close()
      await load()
    } catch (err) {
      setFormError(err instanceof Error ? err.message : 'Gagal menyimpan voucher')
    } finally {
      setBusy(false)
    }
  }

  async function toggleActive(v: Voucher) {
    setError('')
    try {
      await updateVoucher(v.id, { title: v.title, price: v.price, value: v.value, isActive: !v.isActive })
      await load()
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Gagal mengubah status voucher')
    }
  }

  function openDelete(v: Voucher) {
    setDelError('')
    setDelTarget(v)
    delDlg.current?.showModal()
  }

  async function confirmDelete() {
    if (!delTarget) return
    setBusy(true)
    setDelError('')
    try {
      await deleteVoucher(delTarget.id)
      delDlg.current?.close()
      await load()
    } catch (err) {
      setDelError(err instanceof Error ? err.message : 'Gagal menghapus voucher')
    } finally {
      setBusy(false)
    }
  }

  return (
    <div className="space-y-4">
      <div className="flex items-center justify-between">
        <h1 className="text-2xl font-bold">Voucher</h1>
        <div className="flex gap-2">
          <button className="btn btn-ghost btn-sm" onClick={() => void load()} disabled={loading}>
            Muat Ulang
          </button>
          <button className="btn btn-primary btn-sm" onClick={() => openForm()}>
            Tambah Voucher
          </button>
        </div>
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
      ) : items.length === 0 ? (
        <div className="alert">Belum ada voucher.</div>
      ) : (
        <div className="overflow-x-auto">
          <table className="table">
            <thead>
              <tr>
                <th>Judul</th>
                <th>Harga</th>
                <th>Saldo</th>
                <th>Status</th>
                <th>Aksi</th>
              </tr>
            </thead>
            <tbody>
              {items.map((v) => (
                <tr key={v.id}>
                  <td className="font-medium">{v.title}</td>
                  <td>{rupiah(v.price)}</td>
                  <td>{rupiah(v.value)}</td>
                  <td>
                    <span className={`badge ${v.isActive ? 'badge-success' : 'badge-ghost'}`}>
                      {v.isActive ? 'Aktif' : 'Nonaktif'}
                    </span>
                  </td>
                  <td>
                    <div className="flex gap-1">
                      <button className="btn btn-xs" onClick={() => openForm(v)}>
                        Edit
                      </button>
                      <button className="btn btn-xs" onClick={() => void toggleActive(v)}>
                        {v.isActive ? 'Nonaktifkan' : 'Aktifkan'}
                      </button>
                      <button className="btn btn-xs btn-outline btn-error" onClick={() => openDelete(v)}>
                        Hapus
                      </button>
                    </div>
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      )}

      <dialog ref={formDlg} className="modal">
        <div className="modal-box">
          <h3 className="font-bold text-lg">{editing ? 'Edit Voucher' : 'Tambah Voucher'}</h3>
          {formError && (
            <div role="alert" className="alert alert-error mt-2">
              {formError}
            </div>
          )}
          <form onSubmit={save} className="fieldset mt-2">
            <legend className="fieldset-legend">Nama</legend>
            <input
              className="input w-full"
              required
              value={title}
              onChange={(e) => setTitle(e.target.value)}
              placeholder="Voucher Umroh 500rb"
            />
            <legend className="fieldset-legend">Harga</legend>
            <input
              type="number"
              min={0}
              className="input w-full"
              required
              value={price}
              onChange={(e) => setPrice(e.target.value)}
              placeholder="550000"
            />
            <legend className="fieldset-legend">Nilai Saldo</legend>
            <input
              type="number"
              min={0}
              className="input w-full"
              required
              value={value}
              onChange={(e) => setValue(e.target.value)}
              placeholder="500000"
            />
            <label className="label cursor-pointer mt-2">
              <span>Aktif</span>
              <input
                type="checkbox"
                className="checkbox checkbox-primary"
                checked={isActive}
                onChange={(e) => setIsActive(e.target.checked)}
              />
            </label>
            <div className="modal-action">
              <button type="button" className="btn" onClick={() => formDlg.current?.close()}>
                Batal
              </button>
              <button className="btn btn-primary" disabled={busy}>
                {busy && <span className="loading loading-spinner loading-xs" />}
                Simpan
              </button>
            </div>
          </form>
        </div>
        <form method="dialog" className="modal-backdrop">
          <button>close</button>
        </form>
      </dialog>

      <dialog ref={delDlg} className="modal">
        <div className="modal-box">
          <h3 className="font-bold text-lg">Hapus Voucher</h3>
          {delError ? (
            <div role="alert" className="alert alert-error mt-2">
              {delError}
            </div>
          ) : (
            <p className="py-4">
              Yakin hapus <span className="font-semibold">{delTarget?.title}</span>? Tindakan ini tidak bisa
              dibatalkan.
            </p>
          )}
          <div className="modal-action">
            <button className="btn" onClick={() => delDlg.current?.close()}>
              Batal
            </button>
            <button className="btn btn-error" onClick={() => void confirmDelete()} disabled={busy}>
              {busy && <span className="loading loading-spinner loading-xs" />}
              Hapus
            </button>
          </div>
        </div>
        <form method="dialog" className="modal-backdrop">
          <button>close</button>
        </form>
      </dialog>
    </div>
  )
}
