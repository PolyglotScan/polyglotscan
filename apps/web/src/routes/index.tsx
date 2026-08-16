import { A } from "@solidjs/router"
import { Button } from "~/components/ui/button"
import { useI18n } from "~/lib/i18n"

const DOCS = "https://github.com/PolyglotScan/polyglotscan/blob/main/docs/how-to/light-receipts.adoc"
const REPO = "https://github.com/PolyglotScan/polyglotscan"

export default function Home() {
  const { t } = useI18n()
  return (
    <main class="container py-16">
      <div class="mx-auto flex max-w-3xl flex-col items-center text-center">
        <img
          src="/logo.svg"
          alt="PolyglotScan"
          width={160}
          height={160}
          class="mb-8 size-40 drop-shadow-[0_0_24px_hsl(142_71%_45%_/_0.45)]"
        />
        <h1 class="text-4xl font-semibold tracking-tight sm:text-5xl">PolyglotScan</h1>
        <p class="mt-3 text-lg text-muted-foreground">{t().tagline}</p>
        <p class="mt-6 text-pretty text-base leading-relaxed text-foreground/90">{t().lead}</p>
        <p class="mt-3 text-sm text-primary/80">{t().heroHint}</p>
        <div class="mt-8 flex flex-wrap items-center justify-center gap-3">
          <a href={DOCS} rel="noreferrer" target="_blank">
            <Button>{t().ctaDocs}</Button>
          </a>
          <a href={REPO} rel="noreferrer" target="_blank">
            <Button variant="outline">{t().ctaSource}</Button>
          </a>
          <A href="/license">
            <Button variant="ghost">{t().navLicense}</Button>
          </A>
        </div>
      </div>
      <p class="mt-24 text-center text-xs text-muted-foreground">{t().footer}</p>
    </main>
  )
}
