# SugarRun — CGM Data Field for Garmin

## Overview

Connect IQ data field app for Forerunner 970 that displays real-time CGM data from xDrip+/Nightscout via local HTTP endpoint. Designed for use during activities with multiple selectable field types.

## Data Source

- **Endpoint:** `http://127.0.0.1:17580/sgv.json`
- **Protocol:** HTTP GET via `Communications.makeWebRequest()` (proxied through phone)
- **Poll interval:** 60 seconds
- **Response:** JSON array of readings, newest first, ~5 min intervals

### Relevant Fields per Reading

| Field       | Type    | Example            | Usage                          |
|-------------|---------|--------------------|--------------------------------|
| `sgv`       | Number  | 252                | Blood glucose in mg/dL         |
| `delta`     | Number  | 7, 9.5, -3.5       | Change since previous reading  |
| `direction` | String  | `"FortyFiveUp"`    | Trend direction                |
| `date`      | Number  | 1771440048958      | Epoch ms, for "time since"     |

### Direction Values → Custom Arrows

| Direction          | Arrow | Meaning        |
|--------------------|-------|----------------|
| `DoubleUp`         | ⇈     | Rising fast    |
| `SingleUp`         | ↑     | Rising         |
| `FortyFiveUp`      | ↗     | Rising slowly  |
| `Flat`             | →     | Steady         |
| `FortyFiveDown`    | ↘     | Falling slowly |
| `SingleDown`       | ↓     | Falling        |
| `DoubleDown`       | ⇊     | Falling fast   |
| `NONE` / other     | —     | No data        |

All arrows are **custom drawn** (not font glyphs) due to limited Unicode support on Garmin.

## Unit Conversion

Display in **mmol/L**. Conversion: `mmol = sgv / 18.018`. Round to 1 decimal.

Delta also converted and displayed in mmol/L with sign prefix (`+0.4`, `-0.2`).

## Data Fields

The app exposes **6 data fields**, each selectable independently in any activity screen slot.

### 1. BG (Blood Glucose)

- Shows current glucose value in mmol/L
- Example: `14.0`
- No label text
- Color-coded by range (see Color Zones below)

### 2. Arrow (Trend)

- Custom-drawn trend arrow only
- No text, no numbers
- Arrow color matches BG color zone
- Sized to fill the available field area

### 3. Delta

- Change since previous reading in mmol/L
- Sign prefix: `+0.4`, `-0.2`, `0.0`
- No label text

### 4. Time Since

- Minutes since last CGM reading
- Displays as integer: `3` (minutes, no unit suffix needed — it's obvious in context)
- Color turns red/warning if stale (>10 min)

### 5. Graph

Reference: `/Users/persjo/Downloads/share_7677719061902552539.png`

- Mini BG curve over configurable time window
- **Default:** 30 minutes
- **Configurable:** 30 / 60 / 90 / 120 min (app setting)
- **Dark background** (black)
- **Gray line** connecting readings
- **Colored dots** at each reading, color based on zone:
  - Red dot: < 4.0 mmol/L (low)
  - Cyan/blue dot: 4.0–10.0 mmol/L (in range)
  - Orange/yellow dot: > 10.0 mmol/L (high)
- **Reference lines** (horizontal, thin):
  - Red solid line at low threshold (4.0 mmol/L)
  - Red shaded/filled zone below low threshold
  - Orange solid line at high threshold (10.0 mmol/L)
- No axis labels, no grid lines (screen too small)
- Y-axis fixed range: 2–20 mmol/L (covers CGM range without auto-scaling jitter)
- Newest reading on the right

### 6. Combined (Full)

- All-in-one field for a large/full-screen slot
- Layout: `[Arrow] [BG] [Delta] [TimeSince]`
- BG is the largest, dominant element
- Arrow drawn to the left of BG
- Delta and TimeSince smaller, positioned below or to the right
- No label text (no "CGM", no "BG", nothing)
- Color-coded by range

## Color Zones

| Range (mmol/L) | Color   | Meaning  |
|-----------------|---------|----------|
| < 4.0           | Red     | Low      |
| 4.0 – 10.0      | Green   | In range |
| > 10.0          | Yellow  | High     |

These thresholds could be made configurable later, but hardcoded for v1.

## FIT Recording

- Record BG values to the activity FIT file using `session.createField()`
- Enables post-activity analysis in Garmin Connect
- Field name: `"blood_glucose"` (or similar)
- Record at each compute cycle where new data is available
- Store raw mg/dL or mmol/L — TBD based on what Garmin Connect handles best

## App Settings (via Garmin Connect Mobile)

| Setting             | Type    | Default        | Options              |
|---------------------|---------|----------------|----------------------|
| Display Mode        | Enum    | Combined (0)   | Combined, BG, Arrow, Delta, TimeSince, Graph |
| Graph Duration      | Enum    | 30 min         | 30, 60, 90, 120 min |
| Record BG to FIT    | Boolean | true (combined) / false (others) | on/off |

In multi-variant builds, each variant strips the Display Mode picker from settings (the app IS the mode). Graph Duration only shown in combined and graph variants.

## Architecture

### Source Structure (implemented)

```
source/
├── SugarRunApp.mc          # App entry. Creates CgmService on start, stops on stop.
├── CgmService.mc           # HTTP fetch via compute() polling, JSON parse, history buffer.
├── SugarRunView.mc         # Main DataField. 6 display modes, conditional FIT recording, fully custom drawing.
├── Conversions.mc          # Module: mg/dL→mmol/L, direction enum, color zones, parse helpers.
├── ArrowRenderer.mc        # Module: vector-drawn trend arrows via fillPolygon.
├── GraphRenderer.mc        # Module: BG graph with colored dots, dashed ref lines, red low zone.
```

### Multi-Variant Build

CIQ settings are per-app, not per-instance. One SugarRunView handles all 6 display modes via `displayMode` property. To allow independent modes in different activity screen slots, each mode is a **separate app** with its own UUID, built from the same shared source with different property defaults.

```
variants/
├── combined/   # "SugarRun"  — displayMode=0, FIT=on
├── bg/         # "SR BG"     — displayMode=1, FIT=off
├── arrow/      # "SR Arrow"  — displayMode=2, FIT=off
└── graph/      # "SR Graph"  — displayMode=5, FIT=off
```

Each variant has its own `monkey.jungle`, `manifest.xml` (unique UUID), and resource overrides. All share the same `source/` directory.

### CgmService

- Polls xDrip+ every 60 seconds via compute() timestamp check (no Timer.Timer in data fields)
- Parses JSON response into internal data structure
- Stores latest reading + history array (for graph)
- Each variant runs its own CgmService instance (independent HTTP requests, negligible overhead)
- History buffer sized to max graph duration (120 min = ~24 readings)

### Data Flow

```
xDrip+ (phone) → HTTP → CgmService → SugarRunView (mode-specific render)
                                    → FIT recording (if enabled)
```

### Permissions Required

- `Communications` — for HTTP requests
- `FitContributor` — for FIT file recording

### Target Device

- Forerunner 970 (`fr970`)
- Min SDK: 5.2.0

## Constraints & Notes

- **Screen size:** All rendering must be legible on a small watch screen
- **No text labels:** No "CGM", "BG", "mmol" etc. — data only
- **Battery:** 60s poll is conservative enough; HTTP is phone-proxied so low cost on watch
- **Offline:** If fetch fails, show last known data with stale indicator (time since turns red)
- **Data field slots:** Garmin allows configuring activity screens with 1–4+ data fields per page. With multi-variant build, each variant appears as a separate data field in the picker, allowing independent mode per slot.
- **Per-app settings:** CIQ limitation — settings are per-app, not per-instance. Multi-variant build solves this by making each mode a separate app.
