import React from 'react'
import { useProjects, useCreateProject } from '../lib/hooks/useProjects'
import ProjectCard from '../components/ProjectCard'
import Invitations from '../components/Invitations'

export default function DashboardPage() {
  const { data: projects = [], isLoading, refetch } = useProjects()
  const createProject = useCreateProject()

  return (
    <div className="container">
      <div className="page-title">
        <h1>Dashboard</h1>
        <div>
          <button className="btn btn-primary" onClick={() => createProject.mutate({ name: 'New Project', description: '' })}>Create Project</button>
        </div>
      </div>

      {isLoading ? (
        <div className="loading">Loading projects…</div>
      ) : (
        <div>
          <div style={{ marginBottom: 12, color: 'var(--muted)' }}>
            {(() => {
              const raw = localStorage.getItem('pm_user')
              try {
                const u = raw ? JSON.parse(raw) : null
                return `Hello, ${u?.name || u?.email || 'User'}`
              } catch {
                return 'Hello, User'
              }
            })()}
          </div>
          
          {/* Show pending invitations */}
          <Invitations onInvitationResponse={() => refetch()} />
          
          <div className="grid cols-3">
            {projects.map((p) => (
              <ProjectCard key={p.id} project={p} />
            ))}
          </div>
        </div>
      )}
    </div>
  )
}
