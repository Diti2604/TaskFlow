import React, { useState } from 'react'
import { useParams } from 'react-router-dom'
import { useProject, useAddTask, useUpdateTask, useDeleteTask, useUpdateProject } from '../lib/hooks/useProject'
import ProjectMembers from '../components/ProjectMembers'

function TasksContainer({ projectId, isOwner }) {
  const { data: project, isLoading: tasksLoading } = useProject(projectId)
  const updateTask = useUpdateTask()
  const deleteTask = useDeleteTask()

  if (tasksLoading) {
    return <div className="card" style={{ padding: 24 }}><div className="loading">Loading tasks...</div></div>
  }

  return (
    <div className="card" style={{ padding: 24 }}>
      <h2 style={{ marginTop: 0, marginBottom: 16 }}>Tasks</h2>
      <div className="tasks-list">
        {project?.tasks?.length ? (
          project.tasks.map((t) => (
            <div key={t.id} className="task">
              <div>
                <div className="task-title">{t.title}</div>
                <div className="task-meta">{t.status}</div>
              </div>
              <div>
                <button 
                  className="btn" 
                  onClick={() => updateTask.mutate({ 
                    id: t.id, 
                    payload: { status: t.status === 'todo' ? 'in_progress' : 'done' }, 
                    projectId: parseInt(projectId) 
                  })}
                >
                  Advance
                </button>
                {isOwner && (
                  <button 
                    style={{ marginLeft: 8 }} 
                    className="btn" 
                    onClick={() => deleteTask.mutate({ id: t.id, projectId: parseInt(projectId) })}
                  >
                    Delete
                  </button>
                )}
              </div>
            </div>
          ))
        ) : (
          <div className="task-meta">No tasks yet.</div>
        )}
      </div>
    </div>
  )
}

export default function ProjectPage() {
  const { id } = useParams()
  const { data: project, isLoading, refetch } = useProject(id)
  const addTask = useAddTask(id)
  const updateProject = useUpdateProject(id)

  const [title, setTitle] = useState('')
  const [isEditingName, setIsEditingName] = useState(false)
  const [projectName, setProjectName] = useState('')
  const [projectDesc, setProjectDesc] = useState('')

  if (isLoading) return <div className="loading">Loading project...</div>
  if (!project) return <div className="loading">Project not found</div>

  const isOwner = project.user_role === 'owner'

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

      <section style={{ marginTop: 24 }}>
        <TasksContainer projectId={id} isOwner={isOwner} />

        <div style={{ marginTop: 16 }}>
          <input 
            value={title} 
            onChange={(e) => setTitle(e.target.value)} 
            className="input" 
            placeholder="New task title" 
          />
          <button 
            className="btn btn-primary" 
            style={{ marginLeft: 8 }} 
            onClick={onAdd}
          >
            Add Task
          </button>
        </div>
      </section>

      <ProjectMembers 
        project={project} 
        isOwner={isOwner} 
        onMemberChange={() => refetch()}
      />
    </div>
  )
}
