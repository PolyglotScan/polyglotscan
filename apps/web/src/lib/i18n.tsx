import { createContext, createSignal, onMount, useContext, type ParentProps } from "solid-js"

export type Locale = "en" | "de" | "es" | "ja"

const dictionaries = {
  en: {
    tagline: "Full-size preview. Honest black and white.",
    lead: "Scan through WIA, TWAIN, or eSCL. Threshold faded receipts on a zoomable preview instead of a postage-stamp pane.",
    ctaDocs: "How-to: light receipts",
    ctaSource: "Source",
    navLicense: "License",
    lang: "Language",
    heroHint: "Cool-white lamp, green bloom — identity, not a vendor logo.",
    licenseBlurb: "Core and plugins are Brand Guardian License 1.0 Standard. The name and art are reserved. Forks that add ads must rename.",
    footer: "PolyglotScan. Official builds are ad-free."
  },
  de: {
    tagline: "Vollgroße Vorschau. Ehrlich schwarz-weiß.",
    lead: "Scannen über WIA, TWAIN oder eSCL. Schwellwert für blasse Bons in einer zoombaren Vorschau — nicht in einem Briefmarkenfenster.",
    ctaDocs: "Anleitung: blasse Bons",
    ctaSource: "Quellcode",
    navLicense: "Lizenz",
    lang: "Sprache",
    heroHint: "Kaltweiße Leiste, grüne Bloom — Marke, kein Herstellerlogo.",
    licenseBlurb: "Kern und Plugins: Brand Guardian License 1.0 Standard. Name und Grafik vorbehalten. Forks mit Werbung müssen umbenennen.",
    footer: "PolyglotScan. Offizielle Builds sind werbefrei."
  },
  es: {
    tagline: "Vista previa a tamaño real. Blanco y negro sincero.",
    lead: "Escanea con WIA, TWAIN o eSCL. Ajusta el umbral de tickets pálidos en una vista con zoom, no en un sello de correo.",
    ctaDocs: "Guía: tickets claros",
    ctaSource: "Código",
    navLicense: "Licencia",
    lang: "Idioma",
    heroHint: "Barra blanco frío, halo verde — identidad, no logo de fabricante.",
    licenseBlurb: "Núcleo y plugins: Brand Guardian License 1.0 Standard. Nombre y arte reservados. Los forks con anuncios deben cambiar de nombre.",
    footer: "PolyglotScan. Las compilaciones oficiales no llevan anuncios."
  },
  ja: {
    tagline: "実寸プレビュー。正直な白黒。",
    lead: "WIA / TWAIN / eSCL で取り込み。薄いレシートのしきい値は切手サイズではなく、ズームできるプレビューで。",
    ctaDocs: "薄いレシートの手順",
    ctaSource: "ソース",
    navLicense: "ライセンス",
    lang: "言語",
    heroHint: "冷たい白のランプに緑のブルーム — ブランドであり、メーカーロゴではない。",
    licenseBlurb: "コアとプラグインは Brand Guardian License 1.0 Standard。名前と図は予約。広告を足したフォークは改名すること。",
    footer: "PolyglotScan。公式ビルドに広告はありません。"
  }
} as const

export type Dict = (typeof dictionaries)["en"]

const I18nContext = createContext<{
  locale: () => Locale
  setLocale: (l: Locale) => void
  t: () => Dict
}>()

export function I18nProvider(props: ParentProps) {
  const [locale, setLocaleSignal] = createSignal<Locale>("en")

  const setLocale = (l: Locale) => {
    setLocaleSignal(l)
    if (typeof localStorage !== "undefined") localStorage.setItem("polyglotscan.locale", l)
    if (typeof document !== "undefined") document.documentElement.lang = l
  }

  onMount(() => {
    const saved = localStorage.getItem("polyglotscan.locale") as Locale | null
    if (saved && saved in dictionaries) setLocale(saved)
  })

  const t = () => dictionaries[locale()]

  return (
    <I18nContext.Provider value={{ locale, setLocale, t }}>
      {props.children}
    </I18nContext.Provider>
  )
}

export function useI18n() {
  const ctx = useContext(I18nContext)
  if (!ctx) throw new Error("useI18n: missing I18nProvider")
  return ctx
}

export const localeLabels: { id: Locale; label: string }[] = [
  { id: "en", label: "English" },
  { id: "de", label: "Deutsch" },
  { id: "es", label: "Español" },
  { id: "ja", label: "日本語" }
]
