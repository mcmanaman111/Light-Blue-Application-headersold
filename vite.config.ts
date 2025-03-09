import { defineConfig } from 'vite';
import react from '@vitejs/plugin-react';

// This configuration enables automatic reloading when files are changed
export default defineConfig({
  plugins: [react()],
  server: {
    // Hot Module Replacement settings to ensure instant updates
    hmr: true,
    // Watch settings to ensure file changes are detected quickly
    watch: {
      usePolling: true,
      interval: 100
    }
  }
});
