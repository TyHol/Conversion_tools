# Conversion Tools — QField Plugin

A plugin for the [QField](https://qfield.org/) mobile GIS app that converts between coordinate systems, creates points, and adds grid-reference search to the QField locator bar.

> **Version:** 0.2 | **Author:** Tyhol | **Repository:** https://github.com/TyHol/Conversion_tools

---

## Contents

- [Installation](#installation)
- [Main Dialog](#main-dialog)
  - [Grabbing Coordinates](#grabbing-coordinates)
  - [Coordinate Formats](#coordinate-formats)
  - [DMS Input Boxes](#dms-input-boxes)
  - [Action Buttons](#action-buttons)
  - [BIG Display](#big-display)
- [Canvas Menu Tools](#canvas-menu-tools)
- [Paste from Clipboard](#paste-from-clipboard)
- [Grid Reference Search](#grid-reference-search)
- [Settings](#settings)

---

## Installation

To install the plugin, download the plugin from the releases page and follow the plugin installation guide to install the zipped plugin in QField.

---

## Main Dialog

Open the dialog by tapping the plugin button (triangle icon) in the QField toolbar.

[IMAGE: main dialog overview showing all coordinate rows]

### Grabbing Coordinates

Four ways to load a position into the dialog:

| Button | Action |
|---|---|
| **Screencenter** | Uses the map canvas centre point (indicated by the crosshair overlay) |
| **GPS** | Uses the current GPS position (GPS must be active) |
| **Type in** | Type directly into any coordinate box — all other boxes update automatically |
| **Paste from clipboard** | Paste a coordinate from the clipboard — see [Paste from Clipboard](#paste-from-clipboard) |

### Coordinate Formats

The dialog shows coordinates in multiple formats simultaneously. Each row can be shown or hidden in [Settings](#settings).

| Row | Format | Example | Input? |
|---|---|---|---|
| **Irish Grid** | National letter + 5-digit easting + 5-digit northing (EPSG:29903) | `H 54321 89797` | Yes |
| **UK Grid** | Two letters + 5-digit easting + 5-digit northing (EPSG:27700) | `NS 45140 72887` | Yes |
| **Custom 1** | X, Y in any CRS — EPSG code is editable | `313621, 234156` | Yes |
| **Custom 2** | X, Y in a second custom CRS — EPSG code is editable | `53.3498, -6.2603` | Yes |
| **WGS84 Decimal** | Latitude, Longitude in decimal degrees | `53.34980, -6.26031` | Yes |
| **WGS84 DDM** | Degrees + Decimal Minutes | `53° 20.988', -6° 15.619'` | No (display) |
| **WGS84 DMS** | Degrees, Minutes, Decimal Seconds | `53° 20' 59.28", -6° 15' 37.11"` | No (display) |

Each row has a **copy** button (clipboard icon) that copies the displayed value to the clipboard.

By default Custom 1 is set to the project CRS and Custom 2 is set to WGS84 (EPSG:4326). Their EPSG codes can be changed directly in the dialog and reset using the **Reset** button in [Settings](#settings).

[IMAGE: coordinate rows with copy buttons visible]

### DMS Input Boxes

Below the read-only DMS row are six editable boxes for entering Degrees, Minutes and Seconds separately for latitude and longitude. Tap the **update** button (circular arrow icon) to push the DMS values into the main WGS84 box and update all other rows. Long-press the update button to also open the BIG display.

[IMAGE: DMS input boxes]

### Action Buttons

| Button | Tap | Long Press |
|---|---|---|
| **Pan/Zoom** | Pans the map canvas to the coordinate | Zooms to the coordinate (zoom level set in Settings) |
| **Add** | Adds a point to the selected layer — opens the attribute form if **Show form on add** is enabled, otherwise adds silently | — |
| **Navigate/Web** | Sets the QField navigation destination to the coordinate | Opens the coordinate in the external map app selected in Settings |
| **BIG** | Opens the BIG display showing GPS and screen-centre coordinates | Opens the BIG display showing all current text-box values |

[IMAGE: action buttons row]

**Long press** on most buttons gives an alternative function — the main button label describes the primary action.

### BIG Display

Two large-text overlay dialogs for easy reading in the field:

- **BIG (tap):** Shows the current GPS position and the screen centre position, each in Irish Grid / UK Grid and Lat/Long. Tap any value to copy it to the clipboard.
- **BIG (long press):** Shows all the current values from the main dialog text boxes, also copyable by tap.

[IMAGE: BIG dialog showing GPS and screen centre]

---

## Canvas Menu Tools

Long-pressing on the map canvas in QField opens a context menu. The plugin adds four items:

| Item | Function |
|---|---|
| **Add point** | Adds a point feature at the tapped location, opening the attribute form |
| **Navigate/Web** | Opens the tapped location in the external map app (as selected in Settings) |
| **Convert coordinates** | Opens the main dialog pre-loaded with the tapped location's coordinates |
| **Paste location from clipboard** | Parses the clipboard as a coordinate, creates a point and always zooms to it |

[IMAGE: canvas long-press menu showing plugin items]

---

## Paste from Clipboard

The **Paste from clipboard** button (in the main dialog) and the **Paste location from clipboard** item (in the canvas menu) both accept a wide range of coordinate formats from the clipboard.

### Accepted formats

| Format | Example |
|---|---|
| Irish Grid | `H 54321 89797` or `H5432189797` |
| UK Grid | `NS 45140 72887` or `NS4514072887` |
| WGS84 decimal degrees | `53.3498, -6.2603` |
| WGS84 degrees + decimal minutes | `53° 20.988' N, 6° 15.619' W` |
| WGS84 degrees, minutes, seconds | `53° 20' 59" N, 6° 15' 37" W` |
| Projected coordinates (any CRS) | `313621, 234156` |

Spaces within grid references are ignored.

### Format confirmation dialog

Every paste opens a **Confirm coordinate format** dialog before anything is committed. This lets you verify — or correct — how the coordinate has been interpreted.

- The parsed text is shown in an editable field — you can fix typos or paste new text directly
- A dropdown lets you override the detected format
- If you change the text or switch format for a grid reference, the parser re-runs on your edited input
- Tap **Apply** to accept, or **Cancel** to abort

### Paste errors

If the clipboard text cannot be parsed, a dialog opens explaining the likely reason (wrong digit count, unrecognised grid letter, etc.) with the text pre-filled for manual correction.

### Canvas menu paste

The canvas menu **Paste location from clipboard** item always zooms to the pasted point regardless of the **After adding point** setting.

---

## Grid Reference Search

The plugin adds an Irish Grid / UK Grid filter to the QField locator (search bar).

Type the prefix **`grid`** followed by a grid reference to search:

```
grid H 54321 89797      ← Irish Grid
grid SE 58098 29345     ← UK Grid
grid NS4514072887       ← spaces not required
```

The result panel shows the grid reference converted to Decimal Degrees and Degrees + Decimal Minutes. Two actions are available from the result:

- **Navigate** — sets the QField navigation destination to the point
- **Add point** — digitises a point at the location in the active point layer

[IMAGE: locator search bar showing grid result with navigate/add actions]

---

## Settings

Open the settings dialog by tapping the **⚙** button in the main dialog header, or by **long-pressing** the plugin toolbar button.

[IMAGE: settings dialog]

### Add points to

Selects which layer new points are added to. The dropdown lists all editable point layers in the current project. Normal layers and private layers are shown in separate groups. Selecting **Active Layer** uses whatever layer is currently active in the QField layer panel.

### After adding point

Controls what happens to the map view after a point is added, and whether the attribute form opens.

| Option | Effect |
|---|---|
| **don't zoom/pan** | Map view stays where it is |
| **Pan to** | Map canvas pans to centre on the new point |
| **Zoom to** | Map canvas zooms to the new point at the extent set by the zoom preset below |
| **Show form on add** | When checked, the attribute form opens for every new point; when unchecked, points are added silently (note: hard field constraints are not enforced in silent mode) |

The zoom extent is set by the dropdown at the bottom of this frame:

| Preset | Half-width |
|---|---|
| Detail | ~25 m |
| Building | ~50 m |
| Street | ~500 m |
| Town *(default)* | ~2 km |
| Region | ~20 km |
| Country | ~200 km |

The canvas menu **Paste location from clipboard** always zooms to the new point regardless of this setting.

### Display

Checkboxes to show or hide each coordinate format row in the main dialog:

| Checkbox | Controls |
|---|---|
| Irish Grid | Irish Grid row |
| UK Grid | UK Grid row |
| Degrees | WGS84 Decimal Degrees row |
| D M.mm | WGS84 Degrees + Decimal Minutes row |
| D M S.ss | WGS84 Degrees Minutes Seconds row |
| Custom 1 | Custom 1 row |
| Custom 2 | Custom 2 row |
| DMS Boxes | DMS entry boxes |
| Crosshair | Map canvas crosshair overlay |

### External map

Selects which app/service opens when using the **Navigate/Web** long-press or the canvas menu navigate action:

| Option | Opens |
|---|---|
| GMaps pin | Google Maps — drops a pin at the location |
| GMaps nav | Google Maps — opens driving directions to the location |
| OSM | OpenStreetMap — centres the map on the location |
| OSRM route | OSRM routing — routes from your GPS position (or screen centre if no GPS) to the location |

### Format

| Setting | Effect |
|---|---|
| Font Size | Text size in the main dialog (5–25) |
| Decimals (m) | Decimal places for projected coordinates (e.g. Custom 1/2 in metres) |
| Decimals (deg) | Decimal places for geographic coordinates (WGS84 lat/lon) |

### Reset

Restores all settings to their defaults, including Custom 1/2 EPSG codes (Custom 1 → project CRS, Custom 2 → EPSG:4326).

---

*All settings are persisted between sessions.*
