import { defineConfig } from "vite";
import { sveltekit } from "@sveltejs/kit/vite";
import tailwindcss from "@tailwindcss/vite";

const TAURI_DEV_PORT = 5200;
const isTauriDev = process.env.TAURI_ENV_DEBUG !== undefined;

export default defineConfig({
  plugins: [tailwindcss(), sveltekit()],
  server: {
    port: TAURI_DEV_PORT,
    strictPort: true,
    watch: {
      ignored: ["**/src-tauri/**"],
    },
    proxy: {
      "/api": {
        target: "http://127.0.0.1:9089",
        changeOrigin: true,
      },
      "/stream": {
        target: "http://127.0.0.1:9089",
        changeOrigin: true,
        configure: (proxy) => {
          proxy.on("proxyReq", (proxyReq) => {
            proxyReq.setHeader("Cache-Control", "no-cache");
            proxyReq.setHeader("X-Accel-Buffering", "no");
          });
        },
      },
    },
    host: "127.0.0.1",
    hmr: {
      host: "127.0.0.1",
      port: TAURI_DEV_PORT,
      protocol: "ws",
    },
  },
  build: {
    target: isTauriDev ? "esnext" : ["chrome105", "safari15"],
    minify: !isTauriDev ? "esbuild" : false,
    sourcemap: isTauriDev,
    chunkSizeWarningLimit: 1000,
  },
  clearScreen: false,
  envPrefix: ["VITE_", "TAURI_"],
  optimizeDeps: {
    include: ["@xterm/xterm", "@xterm/addon-fit", "@xterm/addon-web-links"],
  },
});
