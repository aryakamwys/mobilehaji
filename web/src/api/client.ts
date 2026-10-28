export interface Member {
  id: number
  name: string
  email: string
  role: string
  referralCode: string
  balance: number
  downlines: number
  parentId: number | null
}

export class ApiError extends Error {
  constructor(
    public status: number,
    message: string,
  ) {
    super(message)
  }
}

const TOKEN_KEY = 'token'
const REFRESH_KEY = 'refreshToken'
const MEMBER_KEY = 'member'

export const getToken = () => localStorage.getItem(TOKEN_KEY)

export function getMember(): Member | null {
  try {
    const raw = localStorage.getItem(MEMBER_KEY)
    return raw ? (JSON.parse(raw) as Member) : null
  } catch {
    return null
  }
}

export function setSession(data: { accessToken: string; refreshToken: string; member: Member }) {
  localStorage.setItem(TOKEN_KEY, data.accessToken)
  localStorage.setItem(REFRESH_KEY, data.refreshToken)
  localStorage.setItem(MEMBER_KEY, JSON.stringify(data.member))
}

export function logout() {
  localStorage.removeItem(TOKEN_KEY)
  localStorage.removeItem(REFRESH_KEY)
  localStorage.removeItem(MEMBER_KEY)
  window.location.assign('/login')
}

async function parse<T>(res: Response): Promise<T> {
  const text = await res.text()
  const body: unknown = text ? JSON.parse(text) : null
  if (!res.ok) {
    const message = (body as { error?: string } | null)?.error ?? `Terjadi kesalahan (${res.status})`
    throw new ApiError(res.status, message)
  }
  return body as T
}

async function refreshOnce(): Promise<boolean> {
  const rt = localStorage.getItem(REFRESH_KEY)
  if (!rt) return false
  try {
    const res = await fetch('/api/auth/refresh', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ refreshToken: rt }),
    })
    if (!res.ok) return false
    const data = await parse<{ accessToken: string; refreshToken: string }>(res)
    localStorage.setItem(TOKEN_KEY, data.accessToken)
    localStorage.setItem(REFRESH_KEY, data.refreshToken)
    return true
  } catch {
    return false
  }
}

export async function api<T>(path: string, opts: { method?: string; body?: unknown } = {}): Promise<T> {
  const doFetch = () => {
    const headers: Record<string, string> = {}
    if (opts.body !== undefined) headers['Content-Type'] = 'application/json'
    const token = getToken()
    if (token) headers.Authorization = `Bearer ${token}`
    return fetch(`/api${path}`, {
      method: opts.method ?? 'GET',
      headers,
      body: opts.body === undefined ? undefined : JSON.stringify(opts.body),
    })
  }

  let res = await doFetch()
  if (res.status === 401 && getToken()) {
    if (await refreshOnce()) {
      res = await doFetch()
    } else {
      logout()
      throw new ApiError(401, 'Sesi berakhir. Silakan masuk kembali.')
    }
  }
  return parse<T>(res)
}
