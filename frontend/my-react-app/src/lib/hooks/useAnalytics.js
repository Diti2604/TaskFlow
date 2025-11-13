import { useQuery } from '@tanstack/react-query'
import api from '../api'

export function useAnalytics() {
  return useQuery({
    queryKey: ['analytics'],
    queryFn: async () => {
      const res = await api.get('/api/analytics')
      return res.data
    },
  })
}
