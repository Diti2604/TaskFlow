import React, { useState } from 'react'
import { useNavigate, useLocation } from 'react-router-dom'

export default function LoginPage() {
  const [name, setName] = useState('')
  const [email, setEmail] = useState('')
  const [isLogin, setIsLogin] = useState(true)
  const navigate = useNavigate()
  const location = useLocation()

  const from = location.state?.from?.pathname || '/'

  function onSubmit(e) {
    e.preventDefault()
    // In this lightweight flow we just store the user locally.
    const user = { name: name || email || 'User', email }
    localStorage.setItem('pm_user', JSON.stringify(user))
    navigate(from, { replace: true })
  }

  return (
    <div style={{ display: 'flex', justifyContent: 'center', paddingTop: 60 }}>
      <div style={{ width: 420 }} className="card">
        <h2 style={{ marginTop: 0 }}>{isLogin ? 'Welcome back' : 'Create an account'}</h2>
        <p className="card-desc">{isLogin ? 'Sign in to continue to TaskFlow' : 'Sign up to create a new TaskFlow account'}</p>
        <form onSubmit={onSubmit} style={{ marginTop: 12 }}>
          <div style={{ marginBottom: 8 }}>
            <label style={{ display: 'block', marginBottom: 6 }}>Name</label>
            <input className="input" value={name} onChange={(e) => setName(e.target.value)} placeholder="Your name" />
          </div>
          <div style={{ marginBottom: 12 }}>
            <label style={{ display: 'block', marginBottom: 6 }}>Email</label>
            <input className="input" value={email} onChange={(e) => setEmail(e.target.value)} placeholder="you@example.com" />
          </div>
          <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
            <button className="btn btn-primary" type="submit">{isLogin ? 'Continue' : 'Sign up'}</button>
            <button type="button" className="btn" onClick={() => setIsLogin((v) => !v)}>{isLogin ? 'Create account' : 'Have an account? Log in'}</button>
          </div>
        </form>
      </div>
    </div>
  )
}
