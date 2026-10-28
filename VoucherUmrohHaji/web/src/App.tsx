import type { ReactElement } from 'react'
import { BrowserRouter, Navigate, Route, Routes } from 'react-router-dom'
import AdminLayout from './components/AdminLayout'
import { getToken } from './api/client'
import Login from './pages/Login'
import Vouchers from './pages/Vouchers'
import MlmConfig from './pages/MlmConfig'
import Approvals from './pages/Approvals'
import Members from './pages/Members'

function RequireAuth({ children }: { children: ReactElement }) {
  return getToken() ? children : <Navigate to="/login" replace />
}

export default function App() {
  return (
    <BrowserRouter>
      <Routes>
        <Route path="/login" element={<Login />} />
        <Route
          element={
            <RequireAuth>
              <AdminLayout />
            </RequireAuth>
          }
        >
          <Route path="/vouchers" element={<Vouchers />} />
          <Route path="/komisi" element={<MlmConfig />} />
          <Route path="/approval" element={<Approvals />} />
          <Route path="/anggota" element={<Members />} />
        </Route>
        <Route path="*" element={<Navigate to="/vouchers" replace />} />
      </Routes>
    </BrowserRouter>
  )
}
