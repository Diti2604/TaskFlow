import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query'
import api from '../api'

export function useProjects() {
  return useQuery({
    queryKey: ['projects'],
    queryFn: async () => {
      const res = await api.get('/api/projects')
      return res.data
    },
  })
}

export function useCreateProject() {
  const qc = useQueryClient()

  return useMutation({
    mutationFn: async (payload) => {
      const res = await api.post('/api/projects', payload)
      return res.data
    },
    onSuccess: () => qc.invalidateQueries({ queryKey: ['projects'] }),
  })
}
