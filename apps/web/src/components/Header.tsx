import { A } from "@solidjs/router"
import { Button } from "~/components/ui/button"
import {
  DropdownMenu,
  DropdownMenuContent,
  DropdownMenuItem,
  DropdownMenuLabel,
  DropdownMenuTrigger
} from "~/components/ui/dropdown-menu"
import { localeLabels, useI18n, type Locale } from "~/lib/i18n"

const REPO = "https://github.com/PolyglotScan/polyglotscan"

export function Header() {
  const { locale, setLocale, t } = useI18n()
  const current = () => localeLabels.find((l) => l.id === locale())?.label ?? "English"

  return (
    <header class="sticky top-0 z-40 border-b border-border/80 bg-background/90 backdrop-blur">
      <div class="container flex h-14 items-center gap-3">
        <A href="/" class="flex items-center gap-2 no-underline text-foreground">
          <img src="/logo.svg" alt="" class="size-8" width={32} height={32} />
          <span class="font-semibold tracking-tight">PolyglotScan</span>
        </A>
        <div class="ml-auto flex items-center gap-2">
          <A href="/license">
            <Button variant="ghost" size="sm">
              {t().navLicense}
            </Button>
          </A>
          <DropdownMenu>
            <DropdownMenuTrigger as={Button} variant="outline" size="sm">
              {t().lang}: {current()}
            </DropdownMenuTrigger>
            <DropdownMenuContent>
              <DropdownMenuLabel>{t().lang}</DropdownMenuLabel>
              {localeLabels.map((item) => (
                <DropdownMenuItem onSelect={() => setLocale(item.id as Locale)}>
                  {item.label}
                </DropdownMenuItem>
              ))}
            </DropdownMenuContent>
          </DropdownMenu>
          <a
            href={REPO}
            class="inline-flex size-10 items-center justify-center rounded-md text-foreground hover:bg-accent"
            aria-label="GitHub"
            rel="noreferrer"
            target="_blank"
          >
            <GitHubIcon />
          </a>
        </div>
      </div>
    </header>
  )
}

function GitHubIcon() {
  return (
    <svg viewBox="0 0 24 24" class="size-5 fill-current" aria-hidden="true">
      <path d="M12 2C6.477 2 2 6.484 2 12.017c0 4.425 2.865 8.18 6.839 9.504.5.092.682-.217.682-.483 0-.237-.008-.868-.013-1.703-2.782.605-3.369-1.343-3.369-1.343-.454-1.158-1.11-1.466-1.11-1.466-.908-.62.069-.608.069-.608 1.003.07 1.531 1.032 1.531 1.032.892 1.53 2.341 1.088 2.91.832.092-.647.35-1.088.636-1.338-2.22-.253-4.555-1.113-4.555-4.951 0-1.093.39-1.988 1.029-2.688-.103-.253-.446-1.272.098-2.65 0 0 .84-.27 2.75 1.026A9.564 9.564 0 0 1 12 6.844a9.24 9.24 0 0 1 2.504.337c1.909-1.296 2.747-1.027 2.747-1.027.546 1.379.202 2.398.1 2.651.64.7 1.028 1.595 1.028 2.688 0 3.848-2.339 4.695-4.566 4.943.359.309.678.92.678 1.855 0 1.338-.012 2.419-.012 2.747 0 .268.18.58.688.482A10.02 10.02 0 0 0 22 12.017C22 6.484 17.522 2 12 2z" />
    </svg>
  )
}
