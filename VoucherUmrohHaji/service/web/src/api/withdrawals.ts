import { api } from './client'

export type WithdrawalStatus = 'pending' | 'approved' | 'rejected'

export interface Withdrawal {
  id: number
  amount: number
  bank: string
  account: string
  holder: string
  status: WithdrawalStatus
  createdAt: string
}

export const listWithdrawals = () => api<Withdrawal[]>('/admin/withdrawals')

export const approveWithdrawal = (id: number) =>
  api<unknown>(`/admin/withdrawals/${id}/approve`, { method: 'POST' })

export const rejectWithdrawal = (id: number) =>
  api<unknown>(`/admin/withdrawals/${id}/reject`, { method: 'POST' })
