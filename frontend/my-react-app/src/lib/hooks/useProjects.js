import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query'
import api from '../api'
import { mockProjects } from '../mockData'

export function useProjects() {
  const isMock = import.meta.env.VITE_MOCK === '1'

  return useQuery({
    queryKey: ['projects'],
    queryFn: async () => {
      if (isMock) return mockProjects
      const res = await api.get('/api/projects')
      return res.data
    },
  })
}

export function useCreateProject() {
  const qc = useQueryClient()
  const isMock = import.meta.env.VITE_MOCK === '1'

  return useMutation({
    mutationFn: async (payload) => {
      if (isMock) {
        const newP = { id: String(Date.now()), ...payload, tasks: [] }
        mockProjects.unshift(newP)
        return newP
      }
      const res = await api.post('/api/projects', payload)
      return res.data
    },
    onSuccess: () => qc.invalidateQueries({ queryKey: ['projects'] }),
  })
}
