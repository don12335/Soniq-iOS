import type { CapacitorConfig } from "@capacitor/cli";

const config: CapacitorConfig = {
  appId: "app.soniq.mobile",
  appName: "Soniq",
  // filled by scripts/build-web.sh from Soniq's `pnpm build:ios` (dist-mobile)
  webDir: "web",
  // Keep the default capacitor://localhost origin: localStorage/IndexedDB (library, history, cache) are tied to it.
  ios: {
    contentInset: "never",
    backgroundColor: "#000000",
    webContentsDebuggingEnabled: true,
  },
  plugins: {
    // Soniq installs its own fetch wrapper that calls CapacitorHttp with per-host headers.
    CapacitorHttp: { enabled: false },
    StatusBar: { overlaysWebView: true },
    Keyboard: { resize: "none" },
  },
};

export default config;
