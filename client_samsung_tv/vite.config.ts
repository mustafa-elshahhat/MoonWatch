import { defineConfig } from 'vite';
import react from '@vitejs/plugin-react';

export default defineConfig({
  plugins: [react()],
  server: {
    host: '0.0.0.0',
    port: 3000,
    strictPort: true,
  },
  preview: {
    host: '0.0.0.0',
    port: 3000,
  },
  build: {
    // Tizen 5.5 (2020 Samsung TVs, the declared minimum in config.xml) runs
    // ~Chromium 76, which lacks optional chaining (?.) and nullish coalescing
    // (??) — those require Chromium 80. Targeting chrome69 forces esbuild to
    // down-level that syntax so the shipped bundle parses on those TVs.
    // If this is raised, re-scan dist/assets/*.js for `?.`/`??` (expect 0).
    target: ['chrome69'],
    outDir: 'dist',
    sourcemap: false,
  },
});
