# Frontend — apps/web

Root `AGENTS.md` applies. These add to it.

## Language

- **EN, RU, PL.** New user-visible text means new keys in all three locale files. English filled; Polish and Russian may be stubbed and tracked, never designed out.
- **No hardcoded strings** — not in templates, not in component code, not in error messages. Write keys as if the CI gate that fails on a missing key is already on.
- Layouts must survive Russian and Polish string lengths. Test with the longest locale, not English.

## Design

- Minimal and content-first — an interface that stays out of the way.
- **Near-neutral chrome, one orange/red accent.** Colour is scarce and reserved for data: air-quality bands need it, navigation does not.
- Use design tokens. No one-off colours, spacing values or font sizes.
- Angular Material with the custom theme. Standalone components. PWA with offline support for saved areas and lists.

## Displaying data

Every value from an external source renders with its provenance — measurement time, source and station distance for a reading; source and last-seen date for a place. **There is no component that takes a bare number.** If the server marks a value stale, that must be visible, not inferred.

Estimates and derived scores are labelled as such in words, not only by styling. A score shows its factors on request — an unexplainable score doesn't ship.

Source attribution is visible in the app itself — OSM's ODbL and Warsaw open data's terms are legal obligations, not an about-page courtesy.

## Errors

Translated, specific, actionable. Never surface a raw upstream error, an HTTP status, or a stack trace.

## Attention

Suggest, never nag. A proactive suggestion ships in the same change as its off switch — master toggle plus granular.
