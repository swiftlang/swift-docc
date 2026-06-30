import { defineConfig } from 'vite'
import vue from '@vitejs/plugin-vue'

// https://vite.dev/config/
export default defineConfig({
  plugins: [vue()],
  build: {
    outDir: 'dist',
    // No code splitting — produce a single app.js and app.css so they can
    // easily be embedded in StaticResources.swift as Data literals.
    // Point directly at the TypeScript entry so no index.html is needed.
    rollupOptions: {
      input: 'src/main.ts',
      output: {
        entryFileNames: 'app.js',
        chunkFileNames: 'app-[hash].js',
        assetFileNames: (assetInfo) =>
          assetInfo.name?.endsWith('.css') ? 'app.css' : '[name][extname]',
      },
    },
    cssCodeSplit: false,
    minify: 'esbuild',
    target: 'es2020',
  },
})
