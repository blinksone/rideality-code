import { defineConfig } from 'vite';

export default defineConfig({
  server: {
    port: 5173,
    proxy: {
      // Avoid browser CORS while talking to the live API.
      '/api': {
        target: 'http://65.21.177.122:3000',
        changeOrigin: true,
      },
      '/uploads': {
        target: 'http://65.21.177.122:3000',
        changeOrigin: true,
      },
    },
  },
});
