import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query'
import api from '../api'

export function useProject(projectId) {
  return useQuery({
    queryKey: ['project', projectId],
    queryFn: async () => {
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
      const res = await api.post(`/api/projects/${projectId}/tasks`, payload)
      return res.data
    },
    onSuccess: () => {
      qc.invalidateQueries({ queryKey: ['project', projectId] })
      qc.invalidateQueries({ queryKey: ['projects'] })
    },
  })
}

export function useUpdateTask() {
  const qc = useQueryClient()
  return useMutation({
    mutationFn: async ({ id, payload }) => {
      const res = await api.patch(`/api/tasks/${id}`, payload)
      return res.data
    },
    onSuccess: (data, variables) => {
      // Invalidate the specific project query
      if (data?.project_id) {
        qc.invalidateQueries({ queryKey: ['project', data.project_id] })
      }
      if (variables?.projectId) {
        qc.invalidateQueries({ queryKey: ['project', variables.projectId] })
      }
      // Invalidate all projects and analytics
      qc.invalidateQueries({ queryKey: ['projects'] })
      qc.invalidateQueries({ queryKey: ['analytics'] })
    },
  })
}

export function useDeleteTask() {
  const qc = useQueryClient()
  return useMutation({
    mutationFn: async ({ id, projectId }) => {
      const res = await api.delete(`/api/tasks/${id}`)
      return { ...res.data, projectId }
    },
    onSuccess: (data) => {
      // Invalidate the specific project query
      if (data?.projectId) {
        qc.invalidateQueries({ queryKey: ['project', data.projectId] })
      }
      // Invalidate all projects and analytics
      qc.invalidateQueries({ queryKey: ['projects'] })
      qc.invalidateQueries({ queryKey: ['analytics'] })
    },
  })
}

export function useUpdateProject(projectId) {
  const qc = useQueryClient()
  return useMutation({
    mutationFn: async (payload) => {
      const res = await api.patch(`/api/projects/${projectId}`, payload)
      return res.data
    },
    onSuccess: () => {
      qc.invalidateQueries({ queryKey: ['project', projectId] })
      qc.invalidateQueries({ queryKey: ['projects'] })
    },
  })
}
