// @refresh reload
import { createHandler, StartServer } from "@solidjs/start/server"

export default createHandler(() => (
  <StartServer
    document={({ assets, children, scripts }) => (
      <html lang="en" class="dark" data-kb-theme="dark">
        <head>
          <meta charset="utf-8" />
          <meta name="viewport" content="width=device-width, initial-scale=1" />
          <meta name="color-scheme" content="dark" />
          <meta
            name="description"
            content="PolyglotScan — native scanner with a full-size preview. WIA, TWAIN, eSCL. Brand Guardian License Standard, reserved brand."
          />
          <link rel="icon" href="/favicon.ico" />
          <link rel="icon" type="image/svg+xml" href="/logo.svg" />
          <link rel="apple-touch-icon" href="/logo-on-dark-256.png" />
          <meta property="og:image" content="/logo-on-dark.png" />
          <title>PolyglotScan</title>
          {assets}
        </head>
        <body>
          <div id="app">{children}</div>
          {scripts}
        </body>
      </html>
    )}
  />
))
