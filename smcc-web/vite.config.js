import { defineConfig } from 'vite'
import react from '@vitejs/plugin-react'

// https://vite.dev/config/
export default defineConfig({
  plugins: [react()],
  server: {
    allowedHosts: ['smcc-web.onrender.com']
  },
  preview: {
    allowedHosts: ['smcc-web.onrender.com']
  }
})
