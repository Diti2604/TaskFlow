import React from 'react'
import { Link } from 'react-router-dom'

export default function ProjectCard({ project }) {
  const total = project.tasks?.length || 0
  const done = project.tasks?.filter((t) => t.status === 'done').length || 0
  const pct = total ? Math.round((done / total) * 100) : 0
  const isShared = project.user_role === 'member'

  return (
    <article className="card">
      <div style={{ display: 'flex', alignItems: 'center', gap: 8, marginBottom: 8 }}>
        <h3 className="card-title" style={{ margin: 0 }}>
          <Link to={`/projects/${project.id}`}>{project.name}</Link>
        </h3>
        {isShared && (
          <span style={{ fontSize: 12, padding: '2px 8px', background: '#e0f2fe', color: '#0369a1', borderRadius: 4 }}>
            Shared
          </span>
        )}
      </div>
      <p className="card-desc">{project.description}</p>
      <div>
        <div className="task-meta">Completion: {pct}%</div>
        <div className="progress"><div className="inner" style={{ width: `${pct}%` }} /></div>
      </div>
    </article>
  )
}
