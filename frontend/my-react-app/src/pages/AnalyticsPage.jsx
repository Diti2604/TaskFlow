import React from 'react'
import { useAnalytics } from '../lib/hooks/useAnalytics'
import { PieChart, Pie, Cell, Tooltip, ResponsiveContainer } from 'recharts'

const COLORS = ['#8884d8', '#82ca9d', '#ffc658']

export default function AnalyticsPage() {
  const { data, isLoading } = useAnalytics()

  if (isLoading) return <div>Loading analytics...</div>

  const pieData = Object.entries(data?.task_status_counts || {}).map(([key, value]) => ({ name: key, value }))

  return (
    <div>
      <h1 className="text-2xl font-semibold mb-4">Analytics</h1>
      <div style={{ width: '100%', height: 300 }} className="bg-white rounded shadow-sm p-4">
        <ResponsiveContainer>
          <PieChart>
            <Pie data={pieData} dataKey="value" nameKey="name" outerRadius={80} fill="#8884d8">
              {pieData.map((entry, idx) => (
                <Cell key={`cell-${idx}`} fill={COLORS[idx % COLORS.length]} />
              ))}
            </Pie>
            <Tooltip />
          </PieChart>
        </ResponsiveContainer>
      </div>
    </div>
  )
}
