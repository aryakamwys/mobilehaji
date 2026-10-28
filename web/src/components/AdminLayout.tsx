import { NavLink, Outlet } from 'react-router-dom'
import { getMember, logout } from '../api/client'

const menu = [
  { to: '/vouchers', label: 'Voucher' },
  { to: '/komisi', label: 'Komisi' },
  { to: '/approval', label: 'Approval' },
  { to: '/anggota', label: 'Anggota' },
]

export default function AdminLayout() {
  const member = getMember()
  return (
    <div className="drawer lg:drawer-open">
      <input id="admin-drawer" type="checkbox" className="drawer-toggle" />
      <div className="drawer-content flex flex-col min-h-screen">
        <div className="navbar bg-base-200">
          <div className="navbar-start gap-1">
            <label htmlFor="admin-drawer" className="btn btn-ghost btn-circle drawer-button lg:hidden" aria-label="buka menu">
              <svg xmlns="http://www.w3.org/2000/svg" className="h-5 w-5" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                <path strokeLinecap="round" strokeLinejoin="round" strokeWidth="2" d="M4 6h16M4 12h16M4 18h16" />
              </svg>
            </label>
            <span className="text-lg font-semibold">Panel Admin</span>
          </div>
          <div className="navbar-end gap-2">
            {member && <span className="text-sm opacity-60 hidden sm:inline">{member.email}</span>}
            <button className="btn btn-ghost" onClick={logout}>
              Keluar
            </button>
          </div>
        </div>
        <main className="flex-1 p-4 lg:p-6">
          <Outlet />
        </main>
      </div>
      <div className="drawer-side">
        <label htmlFor="admin-drawer" aria-label="tutup sidebar" className="drawer-overlay"></label>
        <ul className="menu w-72 min-h-full bg-base-200 p-4 gap-1">
          <li className="menu-title">Voucher Umroh &amp; Haji</li>
          {menu.map((m) => (
            <li key={m.to}>
              <NavLink to={m.to} className={({ isActive }) => (isActive ? 'menu-active' : '')}>
                {m.label}
              </NavLink>
            </li>
          ))}
        </ul>
      </div>
    </div>
  )
}
