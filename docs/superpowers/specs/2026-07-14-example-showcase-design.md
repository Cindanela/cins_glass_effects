# Example showcase page — design

**Date:** 2026-07-14
**Status:** approved (brainstormed with Hanna)

## Purpose

Rebuild the example app as a swipeable specimen gallery so every glass fix can be eyeballed
on-device (Pixel) without single-panel guessing. This is the tooling step that precedes the three
open visual fixes recorded at the top of `WORKLOG.md` (corner mismatch, edge hairlines, FAB seam).

## Structure

A `PageView` — **one specimen per screen**, full-size over a switchable backdrop, with shared
chrome on every page. Registry-driven: adding a specimen (or a future material preset) is one
entry, not a new page widget.

### Files (all under `example/lib/`, replacing the current single demo page)

| File | Contents |
|---|---|
| `main.dart` | App entry → `ShowcasePage` (the `PageView` + shared chrome + all state) |
| `showcase/specimen.dart` | `Specimen` model + the registry list |
| `showcase/specimen_page.dart` | Generic page: one centered glass specimen over the backdrop |
| `showcase/backdrops.dart` | The 3 switchable backdrops |
| `showcase/controls.dart` | Material chips + collapsible slider drawer |
| `showcase/nav_bar_page.dart` | Custom page: nav bar + FAB fixture (reuses `glass_nav_bar.dart`) |
| `showcase/animation_page.dart` | Custom page: `AnimatedGlassContainer` demos |
| `showcase/theme.dart` | Spacing/radius/duration tokens for the gallery chrome |

## Specimen model

```dart
class Specimen {
  final String title;
  final GlassShape Function(Size) shape; // builder — blob needs its center in local coords
  final GlassMaterial defaultMaterial;
  final String checkNote; // one-line "what to eyeball", shown small at the top
}
```

### Registry pages (generic `SpecimenPage`)

1. **Rounded rect** — analytic shader path. Check: corners match the clip exactly; no dark
   hairlines on left/right edges.
2. **Circle** — baked-SDF path.
3. **Squircle** — baked-SDF. Check: superellipse corners smooth, edge band uniform.
4. **Harmonic blob** — `harmonicBlobShape` with a fixed seed (deterministic). Check: curves
   smooth, no staircase.
5. **Star polygon** — concave, via `GlassShape.normalizedPolygon`. Check: concave notches render
   with correct edge optics.

### Custom pages (same chrome, bespoke body)

6. **Nav bar + FAB fixture** — the bar-with-hole + oversized centred FAB. Toggle between:
   - *separate*: bar and FAB as two glass widgets (reproduces the doubled-rim/seam issue), and
   - *union*: one `GlassContainer` with `bar.union(circle)` (the candidate fix).
7. **Animation** — `AnimatedGlassContainer`: tap the panel to tween between the three material
   presets; a slow horizontal drift toggle verifies grain is anchored to the widget (must not swim).

## Shared chrome (every page, including custom ones)

- **Backdrop switcher** — top-right icon, cycles three backdrops:
  1. busy gradient + star grid (refraction obvious),
  2. plain light gray with faint text (hairlines/tint defects obvious),
  3. scrolling list of colorful cards (backdrop tracking + the documented scroll-lag limit).
- **Material chips** — liquid / frosted / clear (`GlassMaterials` presets).
- **Slider drawer** — collapsed by default; sliders for edgeWidth, refraction, chromatic
  aberration, blur, grain, tint opacity, applied over the selected preset via `copyWith`; reset
  button; current values displayed as text so good numbers can be read back for preset re-tuning.
- Page dots + title at the top; swipe to change page.

## State & dependencies

All state (page index, material choice, slider overrides, backdrop index, per-page toggles) lives
in one `StatefulWidget` at the showcase root, passed down as values + callbacks. Rationale:
ephemeral UI state in an example app; adding a state-management dependency to the package example
is worse. **No new dependencies.**

## Testing

Widget tests in `example/test/`:

- every registry page builds without exceptions;
- material chips actually swap the material on the specimen;
- sliders produce a modified material (copyWith applied);
- backdrop cycling switches the backdrop widget;
- nav-bar page toggle swaps between separate and union compositions.

Visual truth stays on-device — that is the page's purpose. Shader optics can't be asserted in
`flutter test`.

## Out of scope

- New engine features, materials, or shapes (the gallery only consumes the public API).
- The three visual fixes themselves (they come after, using this page).
- Localization (dev-only example tooling, not an app).
