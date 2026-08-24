# PRG — administrative boundaries (planned for V1)

Research only. No code implements this yet. `python -m syrenka_ingest areas`
is the loader that will.

PRG (Państwowy Rejestr Granic) is the official register of Polish
administrative boundaries, published by GUGiK. It is the source for
`areas` rows of kind `city`, `district` and `gmina`, because it carries
TERYT — and TERYT is the key invariant 1 rests on.

**Green areas do not come from PRG.** They have no TERYT and no
administrative existence; they come from OSM relations and land in the same
table with `kind = 'green_area'`. That split is why `areas.teryt` is
nullable: required for `city` / `district` / `gmina`, forbidden on
`green_area`. Green areas (and every area row) are keyed by
`(source, source_id)` so a diff-ingest has a durable identity without TERYT.

Two loaders, one table, distinguished by `kind`. Downstream uses `kind` to
split administrative container (`area_id` via `resolve_area_id`) from green
overlay (spatial query). It does not use the loader name, and it does not
treat a Warsaw dzielnica differently from a metro gmina.

---

## What to verify before writing the loader

1. **Layer names and the TERYT column.** PRG ships as GML/SHP with several
   layers; confirm which one holds gmina boundaries and what the TERYT
   attribute is actually called. Warsaw's districts are *dzielnice*, a level
   below gmina, and may live in a different layer than the commuter gminas.
2. **Source SRID.** PRG is published in EPSG:2180, which is also how this
   project stores geometry (`migrations/AGENTS.md`) — confirm before
   reprojecting anything, because a needless round-trip through 4326 loses
   precision for no reason.
3. **Geometry type.** `areas.geom` is `MultiPolygon`; single-polygon rows
   need `ST_Multi` rather than a schema change.
4. **Metro scope.** The download is national. The filter is Warsaw plus the
   commuter gminas named in `AGENTS.md` — Ząbki, Marki, Piaseczno,
   Legionowo, Pruszków, Ożarów, Otwock, Józefów and similar. Filter by TERYT
   code, never by name string.

### TERYT, for the filter above

Warsaw itself is gmina `1465011`. Its eighteen dzielnice sit one level
below gmina and have their own seven-digit codes ending in `8`. The
commuter towns are ordinary gminas with their own codes at the gmina level.
One `teryt` column on `areas` covers all three; `kind` is what distinguishes
them, not the shape of the code.

## Open: how the file gets read

No GDAL-backed library is declared in `services/analytics/pyproject.toml`
yet — deliberately, since nothing in the repository reads a PRG file today.
The choice is between `geopandas`/`pyogrio` (pulls GDAL into every image the
package is installed in) and `ogr2ogr` into a staging table plus plain
`psycopg` (keeps runtime dependencies at one), and it matters more once V8
puts this in Lambda and Fargate.

Not blocking, and not yet decided. Decide it when the loader is written,
not by letting a `pip install` decide it silently.

## Attribution

GUGiK data, per the portal's terms. Like every other source, the obligation
belongs in the app, not only in this file.
