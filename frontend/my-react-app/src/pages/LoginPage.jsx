import React, { useState } from 'react'
import { useNavigate, useLocation } from 'react-router-dom'
import api from '../lib/api'

export default function LoginPage() {
  const [name, setName] = useState('')
  const [password, setPassword] = useState('')
  const [isLogin, setIsLogin] = useState(true)
  const [error, setError] = useState('')
  const [loading, setLoading] = useState(false)
  const navigate = useNavigate()
  const location = useLocation()

  const from = location.state?.from?.pathname || '/'

  async function onSubmit(e) {
    e.preventDefault()
    setError('')
    setLoading(true)

    if (!name || !password) {
      setError('Name and password are required')
      setLoading(false)
      return
    }

    try {
      const endpoint = isLogin ? '/login' : '/signup'
      const payload = { name, password }
      
      const response = await api.post(endpoint, payload)
      
      const user = response.data.user || { name }
      localStorage.setItem('pm_user', JSON.stringify(user))
      localStorage.setItem('userId', user.id)
      
      navigate(from, { replace: true })
    } catch (err) {
      console.error('Auth error:', err)
      setError(err.response?.data?.detail || 'Authentication failed. Please try again.')
    } finally {
      setLoading(false)
    }
  }

  return (
    <div style={{ display: 'flex', justifyContent: 'center', paddingTop: 60 }}>
      <div style={{ width: 420 }} className="card">
        <h2 style={{ marginTop: 0 }}>{isLogin ? 'Welcome back' : 'Create an account'}</h2>
        <p className="card-desc">{isLogin ? 'Sign in to continue to TaskFlow' : 'Sign up to create a new TaskFlow account'}</p>
        
        {error && (
          <div style={{ padding: 12, marginBottom: 12, background: '#fee', color: '#c00', borderRadius: 4 }}>
            {error}
          </div>
        )}
        
        <form onSubmit={onSubmit} style={{ marginTop: 12 }}>
          <div style={{ marginBottom: 8 }}>
            <label style={{ display: 'block', marginBottom: 6 }}>Username *</label>
            <input 
              className="input" 
              value={name} 
              onChange={(e) => setName(e.target.value)} 
              placeholder="Your username" 
              required
            />
          </div>
          
          <div style={{ marginBottom: 8 }}>
            <label style={{ display: 'block', marginBottom: 6 }}>Password *</label>
            <input 
              className="input" 
              type="password"
              value={password} 
              onChange={(e) => setPassword(e.target.value)} 
              placeholder="Your password" 
              required
            />
          </div>
          
          <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginTop: 16 }}>
            <button className="btn btn-primary" type="submit" disabled={loading}>
              {loading ? 'Please wait...' : (isLogin ? 'Log in' : 'Sign up')}
            </button>
            <button type="button" className="btn" onClick={() => { setIsLogin((v) => !v); setError('') }}>
              {isLogin ? 'Create account' : 'Have an account? Log in'}
            </button>
          </div>
        </form>
      </div>
    </div>
  )
}
