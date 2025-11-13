import React from 'react'
import { BrowserRouter, Routes, Route, Link, useLocation } from 'react-router-dom'
import { useNavigate } from 'react-router-dom'
import { QueryClient, QueryClientProvider } from '@tanstack/react-query'
import './index.css'

import DashboardPage from './pages/DashboardPage'
import ProjectPage from './pages/ProjectPage'
import AnalyticsPage from './pages/AnalyticsPage'
import LoginPage from './pages/LoginPage'
import RequireAuth from './lib/RequireAuth'

const queryClient = new QueryClient()

function UserMenu() {
	const navigate = useNavigate()
	const raw = typeof window !== 'undefined' ? localStorage.getItem('pm_user') : null
	let name = ''
	try {
		const u = raw ? JSON.parse(raw) : null
		name = u?.name || u?.email || ''
	} catch {
		name = ''
	}

	function logout() {
		localStorage.removeItem('pm_user')
		localStorage.removeItem('userId')
		navigate('/login')
	}

	return (
		<div style={{ display: 'flex', alignItems: 'center', gap: 8 }}>
			{name ? <div style={{ color: 'var(--muted)' }}>Hi, {name}</div> : null}
			<button className="btn" onClick={logout}>Logout</button>
		</div>
	)
}

function InnerApp() {
	const location = useLocation()
	const hideHeader = location.pathname === '/login'

	return (
		<div>
			{!hideHeader && (
				<header className="app-header">
					<div className="inner">
						<div style={{ display: 'flex', alignItems: 'center', gap: 16 }}>
							<div className="brand"><Link to="/">TaskFlow</Link></div>
							<nav className="nav-links">
								<Link to="/">Dashboard</Link>
								<Link to="/analytics">Analytics</Link>
							</nav>
						</div>
						<UserMenu />
					</div>
				</header>
			)}

			<main>
				<Routes>
					<Route path="/login" element={<LoginPage />} />
					<Route path="/" element={<RequireAuth><DashboardPage /></RequireAuth>} />
					<Route path="/projects/:id" element={<RequireAuth><ProjectPage /></RequireAuth>} />
					<Route path="/analytics" element={<RequireAuth><AnalyticsPage /></RequireAuth>} />
				</Routes>
			</main>
		</div>
	)
}

export default function App() {
	return (
		<QueryClientProvider client={queryClient}>
			<BrowserRouter>
				<InnerApp />
			</BrowserRouter>
		</QueryClientProvider>
	)
}

