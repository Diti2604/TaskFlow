import { useQuery } from '@tanstack/react-query'
import api from '../api'
import { mockAnalytics } from '../mockData'

const IS_MOCK = import.meta.env.VITE_MOCK === '1'

export function useAnalytics() {
  return useQuery({
    queryKey: ['analytics'],
    queryFn: async () => {
      if (IS_MOCK) return mockAnalytics
      const res = await api.get('/api/analytics')
      return res.data
    },
  })
}
