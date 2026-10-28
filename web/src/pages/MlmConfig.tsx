import { useEffect, useState, type FormEvent } from 'react'
import { getReferralMe, saveMlmConfig } from '../api/mlm'

const MAX_LEVELS = 20

export default function MlmConfig() {
  const [levels, setLevels] = useState<string[]>([])
  const [step, setStep] = useState('')
  const [multiplier, setMultiplier] = useState('')
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState('')
  const [success, setSuccess] = useState('')
  const [busy, setBusy] = useState(false)

  async function load() {
    setLoading(true)
    setError('')
    try {
      const me = await getReferralMe()
      setLevels(me.rules.map((r) => String(r.percentage)))
      setStep(String(me.downlineStep))
      setMultiplier(String(me.multiplier))
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Gagal memuat konfigurasi')
    } finally {
      setLoading(false)
    }
  }

  useEffect(() => {
    void load()
  }, [])

  async function save(e: FormEvent) {
    e.preventDefault()
    setBusy(true)
    setError('')
    setSuccess('')
    try {
      await saveMlmConfig({
        levels: levels.map(Number),
        downlineStep: Number(step),
        multiplier: Number(multiplier),
      })
      setSuccess('Konfigurasi komisi tersimpan.')
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Gagal menyimpan konfigurasi')
    } finally {
      setBusy(false)
    }
  }

  return (
    <div className="space-y-4 max-w-2xl">
      <div className="flex items-center justify-between">
        <h1 className="text-2xl font-bold">Komisi (MLM)</h1>
        <button className="btn btn-ghost btn-sm" onClick={() => void load()} disabled={loading}>
          Muat Ulang
        </button>
      </div>

      {error && (
        <div role="alert" className="alert alert-error">
          {error}
        </div>
      )}
      {success && (
        <div role="alert" className="alert alert-success">
          {success}
        </div>
      )}

      {loading ? (
        <div className="flex justify-center py-12">
          <span className="loading loading-spinner loading-lg" />
        </div>
      ) : (
        <form onSubmit={save} className="card bg-base-100 card-border">
          <div className="card-body gap-4">
            <fieldset className="fieldset">
              <legend className="fieldset-legend">Persentase per Level</legend>
              <div className="space-y-2">
                {levels.map((lv, i) => (
                  <div key={i} className="flex items-center gap-2">
                    <span className="w-24 text-sm opacity-70">Level {i + 1}</span>
                    <input
                      type="number"
                      step="any"
                      min={0}
                      required
                      className="input input-sm w-32"
                      value={lv}
                      onChange={(e) =>
                        setLevels((prev) => prev.map((p, j) => (j === i ? e.target.value : p)))
                      }
                    />
                    <span className="text-sm opacity-50">%</span>
                  </div>
                ))}
              </div>
              <div className="flex gap-2 mt-2">
                <button
                  type="button"
                  className="btn btn-sm"
                  disabled={levels.length >= MAX_LEVELS}
                  onClick={() => setLevels((prev) => [...prev, ''])}
                >
                  Tambah Level
                </button>
                <button
                  type="button"
                  className="btn btn-sm"
                  disabled={levels.length <= 1}
                  onClick={() => setLevels((prev) => prev.slice(0, -1))}
                >
                  Hapus Level Terakhir
                </button>
              </div>
              <p className="label">Maksimal {MAX_LEVELS} level.</p>
            </fieldset>

            <div className="grid sm:grid-cols-2 gap-4">
              <fieldset className="fieldset">
                <legend className="fieldset-legend">Step Downline</legend>
                <input
                  type="number"
                  min={1}
                  step="any"
                  required
                  className="input w-full"
                  value={step}
                  onChange={(e) => setStep(e.target.value)}
                />
              </fieldset>
              <fieldset className="fieldset">
                <legend className="fieldset-legend">Faktor Pengali</legend>
                <input
                  type="number"
                  min={0}
                  step="any"
                  required
                  className="input w-full"
                  value={multiplier}
                  onChange={(e) => setMultiplier(e.target.value)}
                />
              </fieldset>
            </div>

            <p className="text-sm opacity-60">
              Contoh: 2 downline dengan faktor 0.5 menghasilkan pengali 1.5×.
            </p>

            <div className="card-actions justify-end">
              <button className="btn btn-primary" disabled={busy}>
                {busy && <span className="loading loading-spinner loading-sm" />}
                Simpan Konfigurasi
              </button>
            </div>
          </div>
        </form>
      )}
    </div>
  )
}
