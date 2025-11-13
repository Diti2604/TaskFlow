import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query'
import api from '../api'
import { mockProjects } from '../mockData'

const IS_MOCK = import.meta.env.VITE_MOCK === '1'

export function useProject(projectId) {
  return useQuery({
    queryKey: ['project', projectId],
    queryFn: async () => {
      if (IS_MOCK) {
        return mockProjects.find((p) => p.id === projectId) || null
      }
      const res = await api.get(`/api/projects/${projectId}`)
      return res.data
    },
    enabled: !!projectId,
  })
}

export function useAddTask(projectId) {
  const qc = useQueryClient()
  return useMutation({
    mutationFn: async (payload) => {
      if (IS_MOCK) {
        const project = mockProjects.find((p) => p.id === projectId)
        if (!project) throw new Error('Project not found')
        const newTask = { id: `m_${Date.now()}`, ...payload }
        project.tasks = project.tasks || []
        project.tasks.push(newTask)
        return newTask
      }
      const res = await api.post(`/api/projects/${projectId}/tasks`, payload)
      return res.data
    },
    onSuccess: () => qc.invalidateQueries({ queryKey: ['project', projectId] }),
  })
}

export function useUpdateTask() {
  const qc = useQueryClient()
  return useMutation({
    mutationFn: async ({ id, payload }) => {
      if (IS_MOCK) {
        // find task and update
        for (const p of mockProjects) {
          const t = p.tasks?.find((x) => x.id === id)
          if (t) {
            Object.assign(t, payload)
            return t
          }
        }
        throw new Error('Task not found')
      }
      const res = await api.put(`/api/tasks/${id}`, payload)
      return res.data
    },
    onSuccess: (_data, variables) => qc.invalidateQueries({ queryKey: ['project', variables?.projectId] }),
  })
}

export function useDeleteTask() {
  const qc = useQueryClient()
  return useMutation({
    mutationFn: async ({ id }) => {
      if (IS_MOCK) {
        for (const p of mockProjects) {
          const idx = p.tasks?.findIndex((x) => x.id === id)
          if (idx >= 0) {
            const [removed] = p.tasks.splice(idx, 1)
            return removed
          }
        }
        throw new Error('Task not found')
      }
      const res = await api.delete(`/api/tasks/${id}`)
      return res.data
    },
    onSuccess: () => qc.invalidateQueries({ queryKey: ['projects'] }),
  })
}
