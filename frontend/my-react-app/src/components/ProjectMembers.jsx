import React, { useState } from 'react'
import api from '../lib/api'

export default function ProjectMembers({ project, isOwner, onMemberChange }) {
  const [searchQuery, setSearchQuery] = useState('')
  const [searchResults, setSearchResults] = useState([])
  const [loading, setLoading] = useState(false)
  const [error, setError] = useState('')

  const handleSearch = async () => {
    if (!searchQuery.trim()) {
      setSearchResults([])
      return
    }
    
    setLoading(true)
    setError('')
    try {
      const res = await api.get('/api/users/search', { params: { query: searchQuery } })
      setSearchResults(res.data)
    } catch (err) {
      setError('Failed to search users')
      setSearchResults([])
    } finally {
      setLoading(false)
    }
  }

  const handleInviteMember = async (username) => {
    setError('')
    try {
      await api.post(`/api/projects/${project.id}/members`, { username })
      setSearchQuery('')
      setSearchResults([])
      alert(`Invitation sent to ${username}!`)
      onMemberChange() // Refresh project data
    } catch (err) {
      setError(err.response?.data?.detail || 'Failed to send invitation')
    }
  }

  const handleRemoveMember = async (userId) => {
    if (!confirm('Remove this member from the project?')) return
    
    setError('')
    try {
      await api.delete(`/api/projects/${project.id}/members/${userId}`)
      onMemberChange() // Refresh project data
    } catch (err) {
      setError(err.response?.data?.detail || 'Failed to remove member')
    }
  }

  return (
    <div className="card" style={{ padding: 24, marginTop: 16 }}>
      <h2 style={{ marginTop: 0, marginBottom: 16 }}>Members</h2>
      
      {/* Current Members */}
      <div style={{ marginBottom: 16 }}>
        <div style={{ fontSize: 14, color: 'var(--muted)', marginBottom: 8 }}>Current members:</div>
        {project.members && project.members.length > 0 ? (
          <div style={{ display: 'flex', flexDirection: 'column', gap: 8 }}>
            {project.members.map((member) => (
              <div key={member.id} style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', padding: 8, background: 'var(--bg)', borderRadius: 4 }}>
                <div>
                  <span style={{ fontWeight: 500 }}>{member.name}</span>
                  <span style={{ marginLeft: 8, fontSize: 12, color: 'var(--muted)' }}>({member.role})</span>
                </div>
                {isOwner && (
                  <button className="btn" onClick={() => handleRemoveMember(member.id)}>
                    Remove
                  </button>
                )}
              </div>
            ))}
          </div>
        ) : (
          <div style={{ color: 'var(--muted)', fontSize: 14 }}>No members yet</div>
        )}
      </div>

      {/* Add Member (only owner) */}
      {isOwner && (
        <div>
          <div style={{ fontSize: 14, color: 'var(--muted)', marginBottom: 8 }}>Invite a member:</div>
          
          {error && (
            <div style={{ padding: 8, marginBottom: 8, background: '#fee', color: '#c00', borderRadius: 4, fontSize: 14 }}>
              {error}
            </div>
          )}
          
          <div style={{ display: 'flex', gap: 8, marginBottom: 8 }}>
            <input
              className="input"
              placeholder="Search by username"
              value={searchQuery}
              onChange={(e) => setSearchQuery(e.target.value)}
              onKeyDown={(e) => e.key === 'Enter' && handleSearch()}
            />
            <button className="btn btn-primary" onClick={handleSearch} disabled={loading}>
              {loading ? 'Searching...' : 'Search'}
            </button>
          </div>

          {/* Search Results */}
          {searchQuery && !loading && searchResults.length === 0 && (
            <div style={{ marginTop: 8, padding: 8, background: 'var(--bg)', borderRadius: 4, color: 'var(--muted)', fontSize: 14 }}>
              No users found with username "{searchQuery}"
            </div>
          )}
          
          {searchResults.length > 0 && (
            <div style={{ marginTop: 8 }}>
              <div style={{ fontSize: 14, color: 'var(--muted)', marginBottom: 8 }}>Search results:</div>
              <div style={{ display: 'flex', flexDirection: 'column', gap: 4 }}>
                {searchResults.map((user) => (
                  <div key={user.id} style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', padding: 8, background: 'var(--bg)', borderRadius: 4 }}>
                    <span>{user.name}</span>
                    <button className="btn btn-primary" onClick={() => handleInviteMember(user.name)}>
                      Invite
                    </button>
                  </div>
                ))}
              </div>
            </div>
          )}
        </div>
      )}
    </div>
  )
}
