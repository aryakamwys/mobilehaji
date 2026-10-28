import { api } from './client'

export interface MlmRule {
  level: number
  percentage: number
}

export interface ReferralMe {
  referralCode: string
  downlines: number
  directDownlines: number
  factorPreview: number
  uplineName: string
  rules: MlmRule[]
  downlineStep: number
  multiplier: number
}

export const getReferralMe = () => api<ReferralMe>('/referral/me')

export function saveMlmConfig(body: { levels: number[]; downlineStep: number; multiplier: number }) {
  return api<unknown>('/admin/mlm-config', { method: 'PUT', body })
}
