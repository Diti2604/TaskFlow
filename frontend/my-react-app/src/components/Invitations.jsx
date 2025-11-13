import React, { useState, useEffect } from 'react'
import api from '../lib/api'
import { showToast } from '../lib/toast'

export default function Invitations({ onInvitationResponse }) {
  const [invitations, setInvitations] = useState([])
  const [loading, setLoading] = useState(true)
  const [processingId, setProcessingId] = useState(null)

  useEffect(() => {
    fetchInvitations()
  }, [])

  const fetchInvitations = async () => {
    try {
      const res = await api.get('/api/invitations')
      setInvitations(res.data)
    } catch (err) {
      console.error('Failed to fetch invitations:', err)
    } finally {
      setLoading(false)
    }
  }

  const handleAccept = async (invitationId, projectName) => {
    setProcessingId(invitationId)
    try {
      await api.post(`/api/invitations/${invitationId}/accept`)
      showToast(`You joined "${projectName}"!`, 'success')
      fetchInvitations() // Refresh invitations
      if (onInvitationResponse) onInvitationResponse() // Refresh projects list
    } catch (err) {
      showToast(err.response?.data?.detail || 'Failed to accept invitation', 'error')
    } finally {
      setProcessingId(null)
    }
  }

  const handleDecline = async (invitationId, projectName) => {
    setProcessingId(invitationId)
    try {
      await api.post(`/api/invitations/${invitationId}/decline`)
      showToast(`Declined invitation to "${projectName}"`, 'info')
      fetchInvitations() // Refresh invitations
    } catch (err) {
      showToast(err.response?.data?.detail || 'Failed to decline invitation', 'error')
    } finally {
      setProcessingId(null)
    }
  }

  if (loading) return null
  if (invitations.length === 0) return null

  return (
    <div className="card" style={{ marginBottom: 24, padding: 24, background: '#fffbeb', border: '2px solid #fbbf24' }}>
      <h3 style={{ marginTop: 0, marginBottom: 16, display: 'flex', alignItems: 'center', gap: 8 }}>
        📬 Pending Invitations
        <span style={{ fontSize: 14, fontWeight: 'normal', color: 'var(--muted)' }}>
          ({invitations.length})
        </span>
      </h3>
      
      <div style={{ display: 'flex', flexDirection: 'column', gap: 12 }}>
        {invitations.map((inv) => (
          <div key={inv.id} style={{ padding: 16, background: 'white', borderRadius: 8, border: '1px solid #e5e7eb' }}>
            <div style={{ marginBottom: 8 }}>
              <strong style={{ fontSize: 16 }}>{inv.project_name}</strong>
              {inv.project_description && (
                <p style={{ margin: '4px 0', color: 'var(--muted)', fontSize: 14 }}>
                  {inv.project_description}
                </p>
              )}
            </div>
            <div style={{ fontSize: 14, color: 'var(--muted)', marginBottom: 12 }}>
              Invited by <strong>{inv.invited_by_name}</strong>
            </div>
            <div style={{ display: 'flex', gap: 8 }}>
              <button 
                className="btn btn-primary" 
                onClick={() => handleAccept(inv.id, inv.project_name)}
                disabled={processingId === inv.id}
              >
                {processingId === inv.id ? 'Accepting...' : 'Accept'}
              </button>
              <button 
                className="btn" 
                onClick={() => handleDecline(inv.id, inv.project_name)}
                disabled={processingId === inv.id}
              >
                {processingId === inv.id ? 'Declining...' : 'Decline'}
              </button>
            </div>
          </div>
        ))}
      </div>
    </div>
  )
}
