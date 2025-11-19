import axios from 'axios'

const API_BASE = import.meta.env.VITE_API_BASE || import.meta.env.VITE_API_URL || 'http://localhost:8000'

const api = axios.create({
  baseURL: API_BASE,
  headers: { 'Content-Type': 'application/json' },
})

api.interceptors.request.use((config) => {
  const userId = localStorage.getItem('userId')
  if (userId) {
    config.params = config.params || {}
    config.params.user_id = userId
  }
  return config
})

export default api
