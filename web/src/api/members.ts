import { api, type Member } from './client'

export interface MembersPage {
  items: Member[]
  totalPages: number
}

export function listMembers(page: number, pageSize = 20) {
  return api<MembersPage>(`/admin/members?page=${page}&pageSize=${pageSize}`)
}
