# GIOŚ — air quality (planned for V2)

Research only. No code implements this yet.

Air quality belongs to V2, alongside weather: a reading is the same shape as a
forecast — a value, measured somewhere, at a known time — both feed the same
comfort score, and this is the feature invariant 2 was written for. It is not
a version of its own.

Field names below were never confirmed against a live response.

---

## The GIOŚ API

The legacy `/pjp-api/rest/*` endpoints were **withdrawn on 30 June 2025**. Everything targets `/pjp-api/v1/rest/*`, which returns JSON-LD with Polish-language wrapper keys and paginated list responses.

| Endpoint                                   | Purpose                                  |
| ------------------------------------------ | ---------------------------------------- |
| `/station/findAll`                         | measurement stations (paged)             |
| `/station/sensors/{stationId}`             | measuring positions at a station         |
| `/data/getData/{sensorId}`                 | current readings for a sensor            |
| `/aqindex/getIndex/{stationId}`            | air quality index for a station          |
| `/archivalData/getDataBySensor/{sensorId}` | historical, by date range or `dayNumber` |

OpenAPI docs: `https://dev.api.gios.gov.pl/pjp-api/swagger-ui/`

### Verify before trusting the parser

Field names in v1 are Polish and were not confirmed against a live response when this was written. Per `services/analytics/AGENTS.md`, the parser must match several candidate spellings per field, diacritic- and case-insensitively, so both v1 and legacy shapes parse — but confirm the real names below and tighten the candidate list once they're known:

```bash
curl -s 'https://api.gios.gov.pl/pjp-api/v1/rest/station/findAll?page=0&size=2' \
  | python -m json.tool | head -60
```

Check two things:

1. **Field names** — station id, name, latitude, longitude; sensor id and parameter code.
2. **Paging** — whether responses carry `totalPages`, and the maximum `size`.

### The rate limit is not one of them

It's documented: **6000 requests per minute overall, across all GIOŚ API interfaces
combined.** That is a system-wide ceiling shared with every other consumer, not a
per-client budget — so the polite reading is the operative one. `GIOS_MIN_INTERVAL`
stays at 1 second: nowhere near the cap, and it keeps a bug in a loop from becoming
a load test. Full metro coverage needs no queue; a paced loop is enough.

Nothing is lost by guessing wrong. Every payload is stored verbatim in `raw_payloads` before parsing — that table is the archive (invariant 4), and it is what re-parsing reads from:

```sql
SELECT endpoint, fetched_at, content_type, sha256, payload_json
FROM raw_payloads ORDER BY fetched_at DESC LIMIT 1;
```

Re-parse from `body` (the byte archive), not from `payload_json`.

Re-parsing is cheap; re-fetching a measurement you didn't save is impossible.

