import React from 'react'
import { Navigate, useLocation } from 'react-router-dom'

export default function RequireAuth({ children }) {
  const location = useLocation()
  const user = typeof window !== 'undefined' ? localStorage.getItem('pm_user') : null
  if (!user) {
    return <Navigate to="/login" state={{ from: location }} replace />
  }
  return children
}
