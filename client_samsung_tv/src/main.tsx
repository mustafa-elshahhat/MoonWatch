import { StrictMode } from 'react';
import { createRoot } from 'react-dom/client';
// Self-hosted brand fonts (offline-safe on Tizen, no CDN dependency).
// Mirrors the Flutter client: Inter (UI), JetBrains Mono (room codes),
// Instrument Serif (hero display).
import '@fontsource-variable/inter/index.css';
import '@fontsource-variable/jetbrains-mono/index.css';
import '@fontsource/instrument-serif/index.css';
import '@fontsource/instrument-serif/400-italic.css';
import App from './App';

createRoot(document.getElementById('root')!).render(
  <StrictMode>
    <App />
  </StrictMode>,
);
