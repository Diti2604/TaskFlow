export const mockProjects = [
  {
    id: '1',
    name: 'Website Redesign',
    description: 'Refresh the marketing website with a modern design.',
    tasks: [
      { id: 't1', title: 'Wireframes', status: 'done' },
      { id: 't2', title: 'Mockups', status: 'in_progress' },
      { id: 't3', title: 'Implement', status: 'todo' },
    ],
  },
  {
    id: '2',
    name: 'Mobile App',
    description: 'Build the initial mobile MVP for iOS and Android.',
    tasks: [
      { id: 't4', title: 'Specs', status: 'done' },
      { id: 't5', title: 'Prototype', status: 'todo' },
    ],
  },
]

export const mockAnalytics = {
  task_status_counts: {
    todo: 3,
    in_progress: 1,
    done: 2,
  },
}
