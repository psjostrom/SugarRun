# SugarRun — Project Context

## What Is This

Garmin Connect IQ data field app for **Forerunner 970** that displays real-time CGM (Continuous Glucose Monitor) data from xDrip+. Written in Monkey C, targeting CIQ SDK 8.4.0. Deployed and verified end-to-end on device.

## Data Source

- **Endpoint:** `http://127.0.0.1:17580/sgv.json` (xDrip+ local web server on phone)
- Returns JSON array of readings, newest first, ~5 min intervals
- Key fields per reading: `sgv` (mg/dL), `delta` (change), `direction` (trend string), `date` (Unix epoch ms)
- Direction values: `DoubleUp`, `SingleUp`, `FortyFiveUp`, `Flat`, `FortyFiveDown`, `SingleDown`, `DoubleDown`, `NONE`

## Architecture

```
source/
├── SugarRunApp.mc      # App entry. Creates CgmService on start, stops on stop.
├── CgmService.mc       # HTTP fetch via compute() polling, JSON parse, history buffer.
├── SugarRunView.mc     # DataField view. 6 display modes, FIT recording, custom drawing.
├── Conversions.mc      # Module: mg/dL→mmol/L, direction enum, color zones, parse helpers.
├── ArrowRenderer.mc    # Module: vector-drawn trend arrows via fillPolygon.
├── GraphRenderer.mc    # Module: BG graph with colored dots, dashed ref lines, red low zone.
```

```
variants/
├── combined/           # "SugarRun"  — displayMode=0, UUID ce9048dd-...
├── bg/                 # "SR BG"     — displayMode=1
├── arrow/              # "SR Arrow"  — displayMode=2
└── graph/              # "SR Graph"  — displayMode=5
```

Each variant has its own `manifest.xml`, `monkey.jungle`, and `resources/` override. The jungle references `../../source` and merges `../../resources;resources`. Variant resources set `AppName` and `displayMode`. Variant `settings.xml` files are stripped (no displayMode picker — the app IS the mode).

| Variant  | App Name  | displayMode | Settings in GCM            |
|----------|-----------|-------------|----------------------------|
| combined | SugarRun  | 0           | displayMode + graphDuration |
| bg       | SR BG     | 1           | (none)                     |
| arrow    | SR Arrow  | 2           | (none)                     |
| graph    | SR Graph  | 5           | graphDuration              |

## Display Modes

| Value | Mode     | What it shows                            |
|-------|----------|------------------------------------------|
| 0     | Combined | Arrow + BG + Delta + TimeSince (default) |
| 1     | BG       | mmol/L value, color-coded                |
| 2     | Arrow    | Trend arrow, color-coded                 |
| 3     | Delta    | Delta (+0.4 mmol/L)                      |
| 4     | TimeSince| Minutes since last reading               |
| 5     | Graph    | BG curve with colored dots               |

## FIT → Springa Pipeline (verified)

```
SugarRun (mg/dL) → FIT "Bloodglucose" → Garmin Connect → Intervals.icu ("bloodglucose" stream) → Springa
```

- FIT field name **must** be `Bloodglucose` — Intervals.icu maps this to stream type `bloodglucose`
- No native FIT field for glucose exists; developer field is the only option
- Springa looks for stream types: `bloodglucose`, `glucose`, `ga_smooth`
- Springa auto-detects mg/dL vs mmol/L (avg > 15 or max > 20 → assumes mg/dL, converts)
- Garmin Connect does NOT display developer fields from side-loaded apps, but stores the raw FIT — data flows through to Intervals.icu regardless
- Springa filters activities by name prefix (e.g. "eco16") — test runs without that prefix won't appear in Springa analysis

## Technical Decisions

- **Units:** Display mmol/L (converted via /18.018). FIT records raw mg/dL.
- **FIT recording:** Always on, unconditional. All variants record. No toggle.
- **Time-since:** `(Time.now().value().toLong() - mLastReadingTime / 1000) / 60`. No epoch offset.
- **Fonts:** Step-down loop across 4 tiers (NUMBER_HOT → NUMBER_MEDIUM → LARGE → MEDIUM). Thresholds tuned for FR970: NUMBER_HOT ≥80px, NUMBER_MEDIUM ≥50px, LARGE ≥35px.
- **Combined layout:** Stacked (2 rows) when roughly square, horizontal (1 row) when w > h×2.
- **Circular screen:** `getObscurityFlags()` adds 12% horizontal / 8% vertical padding on obscured sides.
- **Colors:** BG text uses zone color (red `0xFF5555` <4.0 / green `0x55FF55` 4.0–10.0 / yellow `0xFFDD00` >10.0). Delta is white. TimeSince is white, turns `0xFF5555` when stale (≥10 min).
- **Graph:** Y-range 2–20 mmol/L. Dot radius 4px (2px for fields <150px height). Dots colored by zone.
- **Background:** Forced black (AMOLED optimized).
- **Polling:** `compute()` runs every second. No `Timer.Timer` (unavailable in data fields).
- **No XML layouts:** All rendering via `dc` drawing calls.

## Pitfalls & Lessons Learned

These cost real debugging time. Don't repeat them.

1. **FIT field name determines Intervals.icu stream type.** `Bloodglucose` → `bloodglucose` (works). `blood_glucose` → `blood_glucose` (Springa ignores it). The reference watchface at `~/code/garmin/superstable` uses `Bloodglucose`.

2. **`Time.now().value()` returns Unix epoch seconds.** Not Garmin epoch. No 631065600 offset. The `GARMIN_EPOCH_OFFSET` constant exists only for mock data generation.

3. **TimeSince must use the CGM reading timestamp**, not the HTTP response time. Use `mLastReadingTime` (from xDrip+ `date` field), not `mLastDataReceivedAt`.

4. **Property values persist across side-load installs.** Never gate critical functionality on a property — stale cached values will bite you. FIT recording was originally gated on `enableFitRecording`; now unconditional.

5. **Garmin Connect hides developer fields from side-loaded apps.** Data is in the FIT file (verified with fitparse). Not a code bug.

6. **Font thresholds from simulator don't transfer to device.** Simulator renders fonts differently. Always test sizing on hardware.

7. **`hidden` keyword is invalid in Monkey C modules** — only works in classes.

8. **`instanceof Array` is unreachable in CIQ callbacks** — compiler optimizes it away. Use direct `data as Array` cast.

## Build & Run

**Always build IQ packages (never PRG). Always build ALL four variants.**

```bash
SDK="/Users/persjo/Library/Application Support/Garmin/ConnectIQ/Sdks/connectiq-sdk-mac-8.4.0-2025-12-03-5122605dc"
KEY="$HOME/Library/Application Support/Garmin/ConnectIQ/developer_key.der"

for variant in combined bg arrow graph; do
    "$SDK/bin/monkeyc" -f "variants/$variant/monkey.jungle" -o "build/SR_${variant}.iq" -y "$KEY" -e -r -w
done
```

Deploy: install `.iq` files via Garmin Connect IQ app or side-load to `GARMIN/APPS/`.

## Simulator Testing

`CgmService.loadMockData()` exists but is NOT called. To enable, add `loadMockData()` call in `CgmService.initialize()` and remove before deploying. Mock data uses `GARMIN_EPOCH_OFFSET` for timestamp generation — this is correct only for mock data.

## Reference Codebase

The xDrip watchface at `~/code/garmin/superstable` is a known-working reference for:
- Time-since: `(Time.now().value() - date_ms / 1000) / 60`
- xDrip+ JSON parsing
- FIT field naming: `Bloodglucose` with units `G`

## Next Steps

1. **Fix launcher icon** — Current 24x24, device expects 65x65.
2. **Add `<iq:languages>`** to variant manifests to suppress build warning.
3. **Remove old ghost app** — Previous CIQ store version stuck on watch. Delete from `GARMIN/APPS/` via USB.
4. **Test with eco16-named run** — Verify full Springa fuel analysis works with SugarRun BG data.
