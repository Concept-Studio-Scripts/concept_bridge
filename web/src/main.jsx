import React from 'react'
import ReactDOM from 'react-dom/client'
import Dialogue from './dialogue.jsx'
import './index.css'

const root = document.getElementById('root')
ReactDOM.createRoot(root).render(
  <React.StrictMode>
    <Dialogue />
  </React.StrictMode>,
)

// add hidden to root element
root.classList.add('hidden')
