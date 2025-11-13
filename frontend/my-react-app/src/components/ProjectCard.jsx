import React from 'react'
import { Link } from 'react-router-dom'

export default function ProjectCard({ project }) {
  const total = project.tasks?.length || 0
  const done = project.tasks?.filter((t) => t.status === 'done').length || 0
  const pct = total ? Math.round((done / total) * 100) : 0

  return (
    <article className="card">
      <h3 className="card-title"><Link to={`/projects/${project.id}`}>{project.name}</Link></h3>
      <p className="card-desc">{project.description}</p>
      <div>
        <div className="task-meta">Completion: {pct}%</div>
        <div className="progress"><div className="inner" style={{ width: `${pct}%` }} /></div>
      </div>
    </article>
  )
}
