import React from 'react'

export default function Button({ children, className = '', ...props }) {
  return (
    <button className={`px-3 py-1 rounded ${className}`} {...props}>
      {children}
    </button>
  )
}
