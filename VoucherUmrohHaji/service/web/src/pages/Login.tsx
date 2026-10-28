import { useState, type FormEvent } from 'react'
import { useNavigate } from 'react-router-dom'
import { login } from '../api/auth'
import { setSession } from '../api/client'

export default function Login() {
  const navigate = useNavigate()
  const [email, setEmail] = useState('')
  const [password, setPassword] = useState('')
  const [error, setError] = useState('')
  const [busy, setBusy] = useState(false)

  async function submit(e: FormEvent) {
    e.preventDefault()
    setError('')
    setBusy(true)
    try {
      const res = await login(email, password)
      if (res.member.role !== 'admin') {
        setError('Akun ini bukan admin')
        return
      }
      setSession(res)
      navigate('/vouchers')
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Gagal masuk')
    } finally {
      setBusy(false)
    }
  }

  return (
    <div className="min-h-screen flex items-center justify-center bg-base-200 p-4">
      <div className="card bg-base-100 w-full max-w-sm shadow">
        <div className="card-body">
          <h1 className="text-xl font-bold text-center">Voucher Umroh &amp; Haji — Admin</h1>
          {error && (
            <div role="alert" className="alert alert-error">
              {error}
            </div>
          )}
          <form onSubmit={submit} className="fieldset">
            <legend className="fieldset-legend">Email</legend>
            <input
              type="email"
              required
              autoComplete="username"
              className="input w-full"
              placeholder="admin@haji.local"
              value={email}
              onChange={(e) => setEmail(e.target.value)}
            />
            <legend className="fieldset-legend">Password</legend>
            <input
              type="password"
              required
              autoComplete="current-password"
              className="input w-full"
              placeholder="••••••••"
              value={password}
              onChange={(e) => setPassword(e.target.value)}
            />
            <button className="btn btn-primary mt-4" disabled={busy}>
              {busy && <span className="loading loading-spinner loading-sm" />}
              Masuk
            </button>
          </form>
        </div>
      </div>
    </div>
  )
}
