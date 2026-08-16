import { Router } from "@solidjs/router"
import { FileRoutes } from "@solidjs/start/router"
import { Suspense } from "solid-js"
import { Header } from "~/components/Header"
import { I18nProvider } from "~/lib/i18n"
import "./app.css"

export default function App() {
  return (
    <Router
      root={(props) => (
        <I18nProvider>
          <Header />
          <Suspense>{props.children}</Suspense>
        </I18nProvider>
      )}
    >
      <FileRoutes />
    </Router>
  )
}
