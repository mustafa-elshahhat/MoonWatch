import { defineConfig } from 'vitest/config';
import react from '@vitejs/plugin-react';

// Unit-test config for the Samsung TV client (TV-008). Kept separate from
// vite.config.ts so the production build target (chrome69) is untouched.
export default defineConfig({
  plugins: [react()],
  test: {
    environment: 'jsdom',
    include: ['src/**/*.test.ts', 'src/**/*.test.tsx'],
  },
});
