# Greenhouse Monitoring & Control — **Frontend**
Svelte SPA for real‑time greenhouse telemetry, control, and forecasts. Talks to the Django API, refreshes live every few seconds, and supports CSV/Excel and PDF exports.

## Summary
- **Stack:** Svelte, Chart.js, iro.js (color picker), ExcelJS (export).
- **UI:** live cards (temperature, humidity, soil moisture, light, CO₂, leaf color, water level), 5‑s sensor refresh, 60‑s weather tile.
- **Controls:** Pump/Fan/Light — `AUTO / ON / OFF`; light intensity slider and RGB picker; one‑tap **10 mL** water dose; low‑water alert.
- **Theme:** light/dark toggle; responsive grid.

---

## Repo layout (suggested)
```
src/
  lib/components/         # Cards, charts, controls, color picker wrapper
  lib/api/                # fetch helpers (base URL from env)
  routes/                 # +page.svelte, modular pages
  app.css
static/                   
Dockerfile
vite.config.ts
package.json
.env.example
README.md
```

---

## Environment
Create `.env` (or `.env.local`) with:
```
VITE_API_BASE=http://localhost:8091
VITE_APP_NAME=Greenhouse
VITE_REFRESH_MS=5000
VITE_WEATHER_REFRESH_MS=60000
```
> In production, set `VITE_API_BASE` to your domain (e.g., `https://arashg.ir`).

---

## Run (dev)
```bash
npm install
npm run dev
# open http://localhost:5173
```
**Docker:**
```bash
docker build -t greenhouse-front .
docker run --rm -it -p 3000:3000 -e VITE_API_BASE=http://localhost:8091 greenhouse-front
```

---

## Build (prod)
```bash
npm run build
npm run preview  # or serve the 'build' directory behind Nginx
```
When deployed with Docker Compose, the service is usually exposed at `:3000` (proxied by Nginx in production).

---

## Features
- **Live telemetry cards** with sparkline/Chart.js history, rotated tick labels for small screens.
- **Controls panel** with:
  - Pump: `AUTO / ON / OFF` and one‑tap **10 mL** dose.
  - Fan: `AUTO / ON / OFF` (binary control when EN is shorted on L298N).
  - Lighting: `AUTO / ON / OFF`, **intensity slider** `[0..1]`, **iro.js color picker** (compact → expanded).
- **Forecast view:** 24h horizon from backend GRU job.
- **Exports:** Excel via ExcelJS; optional PDF export module.
- **Theme:** light/dark toggle; remembers preference.

---

## API contract (used by the app)
- `GET {VITE_API_BASE}/api/sensors/latest?window=24h`
- `POST {VITE_API_BASE}/api/control` → `{ channel, mode, value? }`
- `GET {VITE_API_BASE}/api/predictions/latest`
- `GET {VITE_API_BASE}/healthz`

> Schema note: `oxygen_level` was renamed to `soil_moisture`; a new `leaf_color` field was added. The UI binds to the updated names to avoid console errors.

---

## UX details
- Sensor cards poll every **5 s**; weather tile every **60 s**.
- Color picker is minimized by default; click to expand.
- Low‑water alert triggers from ultrasonic tank depth; display logic is in a small helper (threshold configurable).

---

## Troubleshooting
- **CORS / mixed content**: ensure `VITE_API_BASE` is HTTPS when the site is served over HTTPS.
- **Clock drift**: timestamps are rendered with the client’s locale; ensure the backend sends UTC ISO strings.
- **Charts stutter**: reduce refresh rate, cap history points, or debounce chart updates.

---

## License
MIT (code) • CC‑BY‑4.0 for screenshots/media
