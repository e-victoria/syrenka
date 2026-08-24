CREATE EXTENSION IF NOT EXISTS postgis;
CREATE EXTENSION IF NOT EXISTS timescaledb;

-- ============================================================
-- sources
--
-- Registry of external data providers (GIOŚ, OSM, IMGW, GUS BDL,
-- Warsaw open data, PRG / GUGiK, ...). Every raw_payloads row,
-- every areas row, and later every measurement, traces back to
-- one of these by name. There is no seed: the first ingestion
-- run for a source inserts its own row before writing anything
-- that references it.
-- ============================================================

CREATE TABLE sources (
    id          BIGSERIAL PRIMARY KEY,
    name        TEXT UNIQUE NOT NULL,
    description TEXT,
    url         TEXT,
    license     TEXT
);

-- ============================================================
-- areas
--
-- Every location in the app — Warsaw's 18 districts, the metro
-- gminas, the big green areas at the edges — is a row here,
-- distinguished only by `kind`. Nothing downstream may reference
-- a place by name string.
--
-- `area_id` on located rows (places, readings, …) is the smallest
-- containing *administrative* area: kind city, district or gmina.
-- `green_area` rows are spatial overlays, queried by geometry;
-- they are never stored as `area_id`. `resolve_area_id` is the
-- rule. Downstream uses `kind` for that split, never the loader
-- name — a Warsaw dzielnica and a metro gmina stay the same kind
-- of administrative row.
--
-- Population is not a column. It arrives in V5 as
-- indicator_values, with period, source and unit.
-- ============================================================

CREATE TABLE areas (
    id            BIGSERIAL PRIMARY KEY,
    teryt         TEXT UNIQUE,
    parent_id     BIGINT REFERENCES areas (id),
    kind          TEXT NOT NULL CHECK (kind IN ('city', 'district', 'gmina', 'green_area')),
    name_pl       TEXT NOT NULL,
    name_en       TEXT,
    name_ru       TEXT,
    geom          geometry(MultiPolygon, 2180) NOT NULL,
    centroid      geometry(Point, 2180) GENERATED ALWAYS AS (ST_PointOnSurface(geom)) STORED,
    source        TEXT NOT NULL REFERENCES sources (name),
    source_id     TEXT NOT NULL,
    first_seen_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    last_seen_at  TIMESTAMPTZ NOT NULL DEFAULT now(),
    UNIQUE (source, source_id),
    CHECK (parent_id IS NULL OR parent_id <> id),
    CHECK (last_seen_at >= first_seen_at),
    CHECK (
        (kind IN ('city', 'district', 'gmina') AND teryt IS NOT NULL)
        OR (kind = 'green_area' AND teryt IS NULL)
    )
);

-- Storage stays in EPSG:2180 (PUWG 1992, Poland's official planar
-- system) for accurate area and distance math. `teryt` is required
-- for administrative rows and forbidden on green areas, which have
-- no TERYT; their durable key is (source, source_id).
CREATE INDEX areas_parent_id_idx ON areas (parent_id);
CREATE INDEX areas_kind_idx ON areas (kind);
CREATE INDEX areas_geom_gix ON areas USING GIST (geom);
CREATE INDEX areas_centroid_gix ON areas USING GIST (centroid);

-- Smallest covering administrative area for a point in 2180 or
-- 4326. District and gmina outrank city (Warsaw as a whole is the
-- fallback). Green areas are not candidates. NULL if uncovered or
-- if the argument's SRID is neither 2180 nor 4326.
CREATE FUNCTION resolve_area_id(loc geometry)
RETURNS BIGINT
LANGUAGE sql
STABLE
AS $$
    SELECT a.id
    FROM areas a
    WHERE a.kind IN ('city', 'district', 'gmina')
      AND ST_Covers(
          a.geom,
          CASE ST_SRID(loc)
              WHEN 2180 THEN loc
              WHEN 4326 THEN ST_Transform(loc, 2180)
          END
      )
    ORDER BY
        CASE a.kind
            WHEN 'district' THEN 0
            WHEN 'gmina' THEN 0
            WHEN 'city' THEN 1
        END,
        ST_Area(a.geom)
    LIMIT 1
$$;

-- Web output (Leaflet/MapLibre, GeoJSON) needs WGS84 (EPSG:4326).
-- ST_Transform is STABLE, not IMMUTABLE — it depends on
-- `spatial_ref_sys` — so it cannot back a generated column and is
-- exposed as a view instead.
CREATE VIEW areas_web AS
SELECT
    id,
    teryt,
    parent_id,
    kind,
    name_pl,
    name_en,
    name_ru,
    ST_Transform(geom, 4326)     AS geom,
    ST_Transform(centroid, 4326) AS centroid,
    source,
    source_id,
    first_seen_at,
    last_seen_at
FROM areas;

-- ============================================================
-- raw_payloads
--
-- Every external fetch, stored verbatim before parsing or
-- normalization (invariant 4). Re-parsing is cheap; re-fetching a
-- measurement that was never saved is impossible. This is a
-- hypertable: it is a pure append log, chunked by `fetched_at`,
-- created here in the same migration as the table
-- (migrations/AGENTS.md).
--
-- `body` is the archive: the exact response bytes. JSONB is not
-- verbatim — it reorders keys, drops whitespace, and cannot hold
-- GML, ZIP, XML or an HTML error page — so it is never the
-- archive. `payload_json` is an optional parse of a JSON body,
-- convenience only.
-- ============================================================

CREATE TABLE raw_payloads (
    id               BIGSERIAL,
    source           TEXT NOT NULL REFERENCES sources (name),
    endpoint         TEXT,
    url              TEXT,
    http_status      INTEGER,
    fetched_at       TIMESTAMPTZ NOT NULL,
    content_type     TEXT,
    content_encoding TEXT,
    body             BYTEA NOT NULL,
    sha256           TEXT NOT NULL CHECK (sha256 ~ '^[0-9a-f]{64}$'),
    payload_json     JSONB,
    PRIMARY KEY (id, fetched_at)
);

SELECT create_hypertable('raw_payloads', 'fetched_at', chunk_time_interval => INTERVAL '1 month');

CREATE INDEX raw_payloads_source_idx ON raw_payloads (source);
CREATE INDEX raw_payloads_sha256_idx ON raw_payloads (sha256);
