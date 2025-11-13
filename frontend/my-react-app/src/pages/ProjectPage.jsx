import React, { useState } from 'react'
import { useParams } from 'react-router-dom'
import { useProject, useAddTask, useUpdateTask, useDeleteTask, useUpdateProject } from '../lib/hooks/useProject'

export default function ProjectPage() {
  const { id } = useParams()
  const { data: project, isLoading } = useProject(id)
  const addTask = useAddTask(id)
  const updateTask = useUpdateTask()
  const deleteTask = useDeleteTask()
  const updateProject = useUpdateProject(id)

  const [title, setTitle] = useState('')
  const [isEditingName, setIsEditingName] = useState(false)
  const [projectName, setProjectName] = useState('')
  const [projectDesc, setProjectDesc] = useState('')

  if (isLoading) return <div className="loading">Loading project...</div>
  if (!project) return <div className="loading">Project not found</div>

  const onAdd = () => {
    if (!title) return
    addTask.mutate({ title, description: '', due_date: null, assignee_id: null })
    setTitle('')
  }

  const startEdit = () => {
    setProjectName(project.name)
    setProjectDesc(project.description || '')
    setIsEditingName(true)
  }

  const saveProjectName = () => {
    if (!projectName) return
    updateProject.mutate({ name: projectName, description: projectDesc })
    setIsEditingName(false)
  }

  return (
    <div className="container">
      <div className="page-title">
        {isEditingName ? (
          <div>
            <input 
              value={projectName} 
              onChange={(e) => setProjectName(e.target.value)} 
              className="input" 
              placeholder="Project name"
              style={{ marginBottom: 8 }}
            />
            <input 
              value={projectDesc} 
              onChange={(e) => setProjectDesc(e.target.value)} 
              className="input" 
              placeholder="Project description"
              style={{ marginBottom: 8 }}
            />
            <button className="btn btn-primary" onClick={saveProjectName} style={{ marginRight: 8 }}>Save</button>
            <button className="btn" onClick={() => setIsEditingName(false)}>Cancel</button>
          </div>
        ) : (
          <div style={{ display: 'flex', alignItems: 'center', gap: 12 }}>
            <h1>{project.name}</h1>
            <button className="btn" onClick={startEdit}>Rename</button>
          </div>
        )}
      </div>
      {!isEditingName && <p className="card-desc">{project.description}</p>}

      <section>
        <h2 style={{ marginTop: 18 }}>Tasks</h2>
        <div className="tasks-list">
          {project.tasks?.length ? (
            project.tasks.map((t) => (
              <div key={t.id} className="task">
                <div>
                  <div className="task-title">{t.title}</div>
                  <div className="task-meta">{t.status}</div>
                </div>
                <div>
                  <button className="btn" onClick={() => updateTask.mutate({ id: t.id, payload: { status: t.status === 'todo' ? 'in_progress' : 'done' }, projectId: parseInt(id) })}>Advance</button>
                  <button style={{ marginLeft: 8 }} className="btn" onClick={() => deleteTask.mutate({ id: t.id, projectId: parseInt(id) })}>Delete</button>
                </div>
              </div>
            ))
          ) : (
            <div className="task-meta">No tasks yet.</div>
          )}
        </div>

        <div style={{ marginTop: 12 }}>
          <input value={title} onChange={(e) => setTitle(e.target.value)} className="input" placeholder="New task title" />
          <button className="btn btn-primary" style={{ marginLeft: 8 }} onClick={onAdd}>Add Task</button>
        </div>
      </section>
    </div>
  )
}
