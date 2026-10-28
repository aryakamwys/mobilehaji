import { api } from './client'

export interface Voucher {
  id: number
  title: string
  price: number
  value: number
  isActive: boolean
}

export const listVouchers = () => api<Voucher[]>('/admin/vouchers')

export function createVoucher(body: { title: string; price: number; value: number }) {
  return api<Voucher>('/admin/vouchers', { method: 'POST', body })
}

export function updateVoucher(
  id: number,
  body: { title: string; price: number; value: number; isActive: boolean },
) {
  return api<Voucher>(`/admin/vouchers/${id}`, { method: 'PUT', body })
}

export const deleteVoucher = (id: number) => api<unknown>(`/admin/vouchers/${id}`, { method: 'DELETE' })
