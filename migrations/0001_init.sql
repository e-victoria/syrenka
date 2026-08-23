CREATE EXTENSION IF NOT EXISTS postgis;
CREATE EXTENSION IF NOT EXISTS timescaledb;

-- ============================================================
-- areas
--
-- Every location in the app — Warsaw's 18 districts, the metro
-- gminas, the big green areas at the edges — is a row here,
-- distinguished only by `kind`. Nothing downstream may reference
-- a place by name string; everything references `areas.id`.
-- ============================================================

CREATE TABLE areas (
    id         BIGSERIAL PRIMARY KEY,
    teryt      TEXT UNIQUE,
    parent_id  BIGINT REFERENCES areas (id),
    kind       TEXT NOT NULL CHECK (kind IN ('city', 'district', 'gmina', 'green_area')),
    name_pl    TEXT,
    name_en    TEXT,
    name_ru    TEXT,
    geom       geometry(MultiPolygon, 2180),
    centroid   geometry(Point, 2180),
    population INTEGER,
    CHECK (parent_id IS NULL OR parent_id <> id)
);

-- Storage stays in EPSG:2180 (PUWG 1992, Poland's official planar
-- system) for accurate area and distance math. `teryt` is nullable
-- rather than required: green areas and some boundaries won't have
-- an official TERYT code, and a boundary may not be sourced yet
-- (kind and id are the only structural keys here).
CREATE INDEX areas_parent_id_idx ON areas (parent_id);
CREATE INDEX areas_geom_gix ON areas USING GIST (geom);
CREATE INDEX areas_centroid_gix ON areas USING GIST (centroid);

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
    population
FROM areas;

-- ============================================================
-- sources
--
-- Registry of external data providers (GIOŚ, OSM, IMGW, GUS BDL,
-- Warsaw open data, ...). Every raw_payloads row, and later every
-- measurement, traces back to one of these by name.
-- ============================================================

CREATE TABLE sources (
    id          BIGSERIAL PRIMARY KEY,
    name        TEXT UNIQUE NOT NULL,
    description TEXT,
    url         TEXT,
    license     TEXT
);

-- ============================================================
-- raw_payloads
--
-- Every external fetch, stored verbatim before parsing or
-- normalization (invariant 4). Re-parsing is cheap; re-fetching a
-- measurement that was never saved is impossible. This is a
-- hypertable: it is a pure append log, chunked by `fetched_at`,
-- created here in the same migration as the table
-- (migrations/AGENTS.md).
-- ============================================================

CREATE TABLE raw_payloads (
    id          BIGSERIAL,
    source      TEXT NOT NULL REFERENCES sources (name),
    endpoint    TEXT,
    url         TEXT,
    http_status INTEGER,
    fetched_at  TIMESTAMPTZ NOT NULL,
    payload     JSONB,
    sha256      TEXT,
    PRIMARY KEY (id, fetched_at)
);

SELECT create_hypertable('raw_payloads', 'fetched_at', chunk_time_interval => INTERVAL '1 month');

CREATE INDEX raw_payloads_source_idx ON raw_payloads (source);
CREATE INDEX raw_payloads_sha256_idx ON raw_payloads (sha256);
