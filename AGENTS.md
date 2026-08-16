# PolyglotScan — project facts for agents

## Product

Native D desktop scanner. Brand-neutral. Standard scan backends (WIA, TWAIN, eSCL) as the baseline; vendor extras (Epson, later others) as plugins. Does **not** ship or redistributed Epson’s partner SDK.

## Layout

DUB workspace. Libraries live under `libs/` and are named so they can graduate to their own GitHub repos later:

| Package | Role |
|---------|------|
| `polyglotscan:core` | Device model, settings, plugin registry, scan session |
| `polyglotscan:image` | Grayscale, global threshold, Sauvola, histogram |
| `polyglotscan:encode` | PNG, JPEG, JPEG-XL, PDF |
| `polyglotscan:wia` | Windows Image Acquisition (standard) |
| `polyglotscan:twain` | TWAIN 2 DSM (standard) |
| `polyglotscan:escl` | eSCL / AirScan HTTP (standard) |
| `polyglotscan:epson` | Epson-oriented plugin (capability hints, **not** `epsonscan-d`) |
| `polyglotscan:fixture` | File/synthetic backend for UI work without a device |

App: `apps/polyglotscan`. Marketing site: `apps/web` (SolidStart static, solid-ui). UI for the desktop app is dlangui Win32 (no web). Preview widget is GPU-agnostic so a vello-d canvas can replace it when that dlangui backend is a stable dub config.

## License split

- Code: Brand Guardian License 1.0 Standard (https://github.com/dev-centr/brand-guardian-license). Prefer BGL over MPL/MIT if they disagree; do not dual-license the same files.
- Canonical steward of the instrument: Dev-Centr `brand-guardian-license`. Copy the Standard text into `LICENSE`; do not invent SPDX ids.
- `brand/`: reserved Branding. Do not relicense as CC0/MIT. Forks replace the mark. See `TRADEMARK.adoc`.

## Do not

- Name packages, executables, or domains after Epson (or other vendor marks) as if official.
- Vendor Epson Scan SDK binaries or headers (partner-gated).
- Commit `MEMORIES.md`. Workstation facts stay in `$CODE_ROOT/MEMORIES.md`.
