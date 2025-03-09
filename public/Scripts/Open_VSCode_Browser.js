#!/usr/bin/env node

/**
 * This script opens the application in the default browser.
 * It waits a short time for the development server to start before opening.
 */

import { exec } from 'child_process';

// Port to use - should match the one Vite is running on
const PORT = 5173;
const URL = `http://localhost:${PORT}/`;

// Wait for the dev server to start (adjust timeout as needed)
setTimeout(() => {
  console.log(`Opening browser at ${URL}`);
  
  // Platform-specific browser opening commands
  const cmd = process.platform === 'darwin' 
    ? `open "${URL}"` // macOS
    : process.platform === 'win32' 
      ? `start "" "${URL}"` // Windows
      : `xdg-open "${URL}"`; // Linux
  
  // Execute the command
  exec(cmd, (error) => {
    if (error) {
      console.error('Failed to open browser:', error.message);
    } else {
      console.log(`Successfully opened ${URL} in browser`);
    }
  });
}, 3000); // Wait 3 seconds for dev server to start
