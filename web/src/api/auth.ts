import { api, type Member } from './client'

export interface LoginResponse {
  accessToken: string
  refreshToken: string
  expiresIn: number
  member: Member
}

export function login(email: string, password: string) {
  return api<LoginResponse>('/auth/login', { method: 'POST', body: { email, password } })
}
