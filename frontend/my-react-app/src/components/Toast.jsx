import React, { useState, useEffect } from 'react'
import { registerToast, unregisterToast } from '../lib/toast'

export default function Toast() {
  const [toast, setToast] = useState(null)

  useEffect(() => {
    const callback = (message, type) => {
      setToast({ message, type })
      setTimeout(() => setToast(null), 4000)
    }
    registerToast(callback)
    return () => {
      unregisterToast()
    }
  }, [])

  if (!toast) return null

  const bgColor = toast.type === 'success' ? '#10b981' : toast.type === 'error' ? '#ef4444' : '#3b82f6'

  return (
    <div
      style={{
        position: 'fixed',
        top: 24,
        right: 24,
        background: bgColor,
        color: 'white',
        padding: '12px 24px',
        borderRadius: 8,
        boxShadow: '0 4px 12px rgba(0,0,0,0.15)',
        zIndex: 9999,
        animation: 'slideIn 0.3s ease-out',
        maxWidth: 400,
      }}
    >
      {toast.message}
    </div>
  )
}
