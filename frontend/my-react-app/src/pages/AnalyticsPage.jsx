import React from 'react'
import { useAnalytics } from '../lib/hooks/useAnalytics'
import { PieChart, Pie, Cell, Tooltip, ResponsiveContainer, Legend } from 'recharts'

const COLORS = ['#8884d8', '#82ca9d', '#ffc658']
const STATUS_LABELS = {
  todo: 'To Do',
  in_progress: 'In Progress',
  done: 'Done'
}

export default function AnalyticsPage() {
  const { data, isLoading } = useAnalytics()

  if (isLoading) return <div className="container"><div className="loading">Loading analytics...</div></div>

  const pieData = Object.entries(data?.task_status_counts || {}).map(([key, value]) => ({ 
    name: STATUS_LABELS[key] || key, 
    value 
  }))

  const totalTasks = pieData.reduce((sum, item) => sum + item.value, 0)

  return (
    <div className="container">
      <div className="page-title">
        <h1>Analytics</h1>
      </div>

      <div style={{ marginBottom: 24 }}>
        <div style={{ marginBottom: 12, color: 'var(--muted)' }}>
          Task Status Overview
        </div>
        <div className="card" style={{ padding: 24 }}>
          <div style={{ marginBottom: 16, fontSize: 18, fontWeight: 500 }}>
            Total Tasks: {totalTasks}
          </div>
          <div style={{ width: '100%', height: 300 }}>
            <ResponsiveContainer>
              <PieChart>
                <Pie 
                  data={pieData} 
                  dataKey="value" 
                  nameKey="name" 
                  cx="50%" 
                  cy="50%" 
                  outerRadius={100} 
                  fill="#8884d8"
                  label
                >
                  {pieData.map((entry, idx) => (
                    <Cell key={`cell-${idx}`} fill={COLORS[idx % COLORS.length]} />
                  ))}
                </Pie>
                <Tooltip />
                <Legend />
              </PieChart>
            </ResponsiveContainer>
          </div>
        </div>
      </div>

      <div className="grid cols-3">
        {Object.entries(data?.task_status_counts || {}).map(([status, count]) => (
          <div key={status} className="card">
            <div style={{ fontSize: 14, color: 'var(--muted)', marginBottom: 8 }}>
              {STATUS_LABELS[status] || status}
            </div>
            <div style={{ fontSize: 32, fontWeight: 600 }}>{count}</div>
          </div>
        ))}
      </div>
    </div>
  )
}
