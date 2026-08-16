import { A } from "@solidjs/router"
import { useI18n } from "~/lib/i18n"

export default function LicensePage() {
  const { t } = useI18n()
  return (
    <main class="container max-w-2xl py-16">
      <h1 class="text-3xl font-semibold tracking-tight">{t().navLicense}</h1>
      <p class="mt-4 leading-relaxed text-foreground/90">{t().licenseBlurb}</p>
      <ul class="mt-6 list-disc space-y-2 pl-5 text-sm text-muted-foreground">
        <li>
          <a class="text-primary underline-offset-4 hover:underline" href="https://github.com/PolyglotScan/polyglotscan/blob/main/LICENSE">
            Brand Guardian License 1.0 Standard
          </a>
        </li>
        <li>
          <a class="text-primary underline-offset-4 hover:underline" href="https://github.com/PolyglotScan/polyglotscan/blob/main/LICENSING.adoc">
            LICENSING.adoc
          </a>
        </li>
        <li>
          <a class="text-primary underline-offset-4 hover:underline" href="https://github.com/PolyglotScan/polyglotscan/blob/main/TRADEMARK.adoc">
            TRADEMARK.adoc
          </a>
        </li>
        <li>
          <a class="text-primary underline-offset-4 hover:underline" href="https://github.com/PolyglotScan/polyglotscan/blob/main/brand/LICENSE">
            brand/LICENSE
          </a>
        </li>
        <li>
          <a class="text-primary underline-offset-4 hover:underline" href="https://github.com/dev-centr/brand-guardian-license">
            Canonical Brand Guardian License texts
          </a>
        </li>
      </ul>
      <p class="mt-8">
        <A href="/" class="text-sm text-primary underline-offset-4 hover:underline">
          ← PolyglotScan
        </A>
      </p>
    </main>
  )
}
