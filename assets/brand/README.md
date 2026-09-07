# Owl brand assets

A compact tawny owl tilts its head while holding one multicolored feather. Cream facial discs and amber eyes stay legible against the new night-aperture field.

## Use by surface

| Surface | Asset | Treatment |
| --- | --- | --- |
| README header / large gallery | `assets/brand/icon-rounded.png` | Selected rounded presentation, shown at 128 px in README |
| Small popover header | `logo.png` → app bundle `Resources/logo.png` | Transparent foreground; no SwiftUI corner clip. |
| Preferences header | App bundle `Resources/AppIcon.icns` | Native presentation at 120 CSS-independent points; no second rounded clip. Development fallback may use the transparent logo. |
| Native app / Finder icon | `assets/brand/app-icon-macos.png` → `AppIcon.icns` | 824 px rounded tile centered on a transparent 1024 px canvas; build supplies all ten conventional iconset entries. |
| Menu-bar status indicator | System `bird` / `bird.fill` symbols in `StatusItemConfig` | Semantic status symbols rather than the old raster mascot. Their template tinting, severity dots, pulses, labels, and recovery behavior remain intact. |

Root `logo.png` is the canonical 2048 × 2048 transparent foreground. `assets/brand/icon.png` and `icon-rounded.png` are separate square and rounded presentation masters. Small application and browser marks use the transparent foreground without a baked-in background, glow, color filter, or extra circular mask. Larger README, native-install, and social surfaces may use the designed background according to their platform contract.

## Rebuild and provenance

```sh
uv run --with pillow python scripts/resize-logos.py
```

One native image request. Azure Foundry `gpt-image-2`, native 2048 × 2048; selected study `2026-09-07-01`, finishing `01`. The owner delegated intermediate acceptance for this named five-project batch. The recorded agent inspection is not a claim that the owner reviewed the returned image bytes.

The smallest protected-feature clearance is **193.5 px** against the actual 23% rounded outline. Intentional lower neck/shoulder intersections are recorded separately; no expressive feature or accessory is clipped. The selected extraction preserves every fully opaque native RGB pixel. All artwork, background, grain, and shadow layers remain separate in the Hexly study.

The presentation uses **Night aperture relief**, with base `#5f6684`, light `#a8aec5`, shade `#363c55`, and motif `#262a43`. Product UI colors remain independent. [source.json](source.json) records exact master hashes and the prior source identity.

- [Individual before/after page](https://hexly.ai/logos/owl)
- [Complete generation and finishing archive](https://github.com/nocoo/hexly.ai/tree/main/artwork/logo-family/owl/2026-09-07-01)
- [Local static review](https://index.dev.hexly.ai/artwork/logo-family/owl/2026-09-07-01/review.html)
- [Shared usage SOP](https://github.com/nocoo/hexly.ai/blob/main/docs/07-logo-usage-sop.md)

The native icon generator supplies its own rounded silhouette and a 100 px inset on each side. `scripts/build.sh` turns that canvas into the conventional ten iconset entries and an ICNS. The root historical `owl.png` name is retired; the app bundle now loads `logo.png`. Menu-bar semantic SF Symbols and the four status colors remain independent of this raster identity.
