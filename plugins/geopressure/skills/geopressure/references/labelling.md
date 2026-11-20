# Labelling a track: guide for agents

How to label flights, pressure and twilights so that GeoPressureR can locate the bird. An agent
prepares label proposals and the evidence for them; the user reviews and decides (section 9).

Written for GeoPressureR 3.9.1. The checks used here (`tag_label_check()`, `pressurepath_check()`,
`tag_label_stapelev()`, `twilight_check()`, `tag$map_pressure$stapelev`) need 3.9.1 or later. The
functions are exported, but `pressurepath_check()`, `tag_label_stapelev()` and `twilight_check()`
are not in the website's reference index: read their help with `?fn` in R. With an older
version, propose updating (the user decides), or use the apps: the TRAINSET Check button,
`plot_pressurepath(type = "hist")`, `plot_twl_calib()`. Check every function and default against
the installed version before relying on it.

The numbers marked "published" come from the GeoLocator Data Packages published by November 2026
(v1.3, residuals along the most likely path). They describe what careful people produced, measured
mostly on 5–30 min data, not limits. Compare a tag mainly with itself, before and after a change.

Read alongside: Manual chapters `labelling-tracks`, `pressurepath`, `geopressureviz`, `geolightviz`;
the worked cases in `https://raw.githubusercontent.com/GeoPressure/GeoPressureManual/main/label-tips.qmd`;
in a Template project, its `AGENTS.md`. Where the Manual suggests discarding more and seeing whether
the position improves, follow this guide instead: that is the self-confirming loop of section 3.

Contents: 1 Goal · 2 How labels are used · 3 The principle and the guardrails · 4 Procedure ·
5 Decision rules · 6 Hard cases · 7 Published examples · 8 Pitfalls · 9 Working with the user ·
10 Recipes · 11 Where no rule exists.

---

## 1. Goal

- **Stationary periods (staps) and flights.** Flight labels define when the bird moved and for how
  long. Flight duration bounds the distance between positions, so a flight cut short or a stop split
  in two moves the trajectory.
- **One pressure series per place and height.** Within a stap, kept pressure points come from one
  location (±10–50 km) and one height. Height changes smaller than the noise (about 0.5 hPa, 5 m)
  cannot be seen and need no label. A bird that sits at clearly different heights gets elevation
  levels (`elev_n`); points at no consistent height are `discard`.
- **Twilights that reflect the place**: discard the ones distorted by shade, cavities or artificial
  light, without trimming the natural scatter.

A good label set makes the residual (tag − ERA5 at the true position, mean removed per level) look
like weather-model noise: one mode, no steps, no day/night cycle.

## 2. How labels are used

### 2.1 Labels

Only `""`, `flight`, `discard` and `elev_<n>` are accepted on pressure and acceleration. Twilight
files accept anything, but only `discard` has an effect.

| Label | On acceleration | On pressure |
|---|---|---|
| `flight` | Defines the staps | Defines staps only without acceleration labels (or outside their time range); otherwise ignored for staps, with a warning, but still removed from the maps |
| `discard` | No effect | Removed from maps, normalisation and checks |
| `elev_<n>` | Ignored | A separate elevation level in that stap. Numbers are local to each stap; unlabelled points are level 0 |
| `""` | Not flight | Ground data, level 0 |

### 2.2 From labels to stationary periods

- Every run of consecutive `flight` samples splits the track: **one flight sample is enough to
  create a new stap**.
- Take-off and landing sit half a sampling interval outside the flight samples. Label every sample
  in flight, descent included.
- Samples during a flight get a fractional `stap_id`; twilights during a flight are dropped.

### 2.3 From pressure labels to the pressure map

`geopressure_map_preprocess()` drops `flight` and `discard`, splits each stap into levels
(stapelev, `"<stap_id>|<level>"`), smooths each to about 1 h and keeps exact hours. It stops if a
stap has no point left. Per level, the GeoPressure API computes:

- **MSE (shape)**: the variance of tag − ERA5 after removing each mean. Each level gets its own
  offset, so levels never bias each other. It discriminates on weather patterns, over hundreds of
  km. At most `max_sample` points per level are used.
- **Mask (level)**: the share of the level's points whose altitude lies within the pixel's ground
  elevation range ± `margin` (in metres). A pixel passes if the share is at least `thr_mask`.
  **Each level must pass on its own: one failing level removes the pixel for the whole stap.**

The likelihood grows only with log(n) of the points: a day of data is weak evidence, ten days much
stronger. `sd` is set per stap, not per level. See `?geopressure_map` for the parameters.

| Mistake | MSE (shape) | Mask (level) |
|---|---|---|
| Altitude step left inside a level | Inflated everywhere; the best pixel can move to wherever ERA5 happens to trend alike | If more than `1 − thr_mask` of the level is off the ground range, the true pixel is removed (worst in flat terrain) |
| Two heights mixed in one level | Inflated, biased | Can fail |
| Unlabelled flight points | Dominated by huge outliers | Above the ground: often an all-zero map |
| Data before attachment / after retrieval | Another place's weather | Office or car altitude can remove the true site |
| Short, noisy `elev_n` level | Adds little | Full veto: 1 bad point in 3 fails a 0.9 threshold |
| Sensor offset or slow drift | Drift inflates it on long stays | Altitude out of the ground range, mostly in lowlands |
| Over-discarding | Fewer points, weaker evidence | None, unless a whole extreme level is dropped (its relief constraint is lost) |

Keeping both the highest and the lowest clean level helps: the pixel must hold both altitudes, which
rules out flat areas for a bird moving between valley and slope.

**An all-zero map** means no pixel lets every level sit on the ground: a step or flight left in a
stap, two heights mixed, pre-attachment data, a sensor offset, or a true position outside the
`extent`. `geopressure_map()` warns and names the level(s) that fit no pixel on their own. Birds on
water or a coast can also look like this, because water pixels are excluded.

`tag$map_pressure$stapelev` keeps one row per stap and level, before the levels are combined:
`nb_sample`, `n_pixel` (land), `n_valid` (passing the mask) and `mse_min` (hPa², best pixel). With
`geopressure_map(keep_mask_split = TRUE)` it also has `frac_above` and `frac_below`: over the pixels
the mask rejects, the mean share of points that would put the bird above the ground (flight, perch,
unlabelled climb: a labelling problem) or below it (sensor offset, or a valley lower than the
pixel). The warning then says "mostly above" or "mostly below the ground".

### 2.4 Pressure along a path

- `geopressure_timeseries(lat, lon, pressure = p)` gives ERA5 at one position; normalisation is per
  elevation level, not per stap, so pass one stap at a time.
- `pressurepath_create(tag, path)` does a whole path, normalised per stap and level. It uses raw
  pressure, so its residuals include sub-hourly noise that the map never sees.
- `pressurepath_check()` returns, per stap and level, the numbers that
  `plot_pressurepath(type = "hist")` shows (orange panels: empirical sd above `sd`). It works on
  either output.
- With an ECMWF key stored (`ecmwfr`), `source = "auto"` (the default) reads ERA5 from ARCO, which
  is faster than the API for repeated single-stap queries and gives the same values. The pressure
  maps always use the API.
- What produced a result is in `tag$param$provenance` and `attr(x, "provenance")`.

### 2.5 Twilights

A discarded twilight leaves the calibration, its own likelihood and the stap's light map. A stap
with no twilight left gets a uniform light map. `plot_twl_calib(tag, path)` marks staps with a
twilight outside the calibrated range; `twilight_check(tag, path)` gives the same test per twilight
(`zenith` at the path position, `outside_ci`).

## 3. The principle and the guardrails

The residual depends on the position used to compute it. Away from the true site, ERA5 has another
weather trace, and the residual shows trends, steps or a day cycle that are not the bird's. **A
label set against a wrong position confirms itself**: discarding what disagrees with a wrong place
makes that place fit, and the map then points there more strongly.

So:

1. Start with labels that need no position: flights, gross outliers, obvious steps, and levels
   found with the position-free scan of section 10.
2. Get a position from the map, check that it is plausible, and compute the residual there.
3. Label only what is clear at that position; leave doubtful points in.
4. Recompute the map; if the position moves, recompute the residual before labelling more.
5. Tighten gradually, until positions stop moving and the remaining flags are explained.

More discard does not buy a better fit: in published tags, the most-discarded third has the worst
residuals and twice the share of two-mode stays. A noisy point costs a little precision; a wrong
discard can move the bird.

### 3.1 Guardrails against over-labelling

Over-labelling is the typical agent mistake: every residual can be made smaller by removing or
relabelling the points that disagree, and the checks then look good while the position is wrong.
This section is the single reference for limits; the rest of the guide points here.

**Evidence needed.** Prefer evidence in the tag's own data, which does not depend on a position:

| Change | Enough evidence | Not enough on its own |
|---|---|---|
| `flight` | High activity **and** a pressure change with a new ground level after it; or, without activity, a fast pressure change to a new ground level, at any time of day | A residual at a position; a large jump that comes back to the same level |
| `discard` of a spike or an edge point | 1–2 points > 5 hPa off their neighbours in the raw pressure, or > 3·`sd` off the running median of the residual at a plausible position (counted by `n_outlier`); or still descending at a stap edge | — |
| `elev_n` | Abrupt steps in the raw pressure (within one or two samples) that return to the same offset at least twice, or a day/night alternation; confirmed in the residual at a plausible position | A residual that drifts slowly, or a split seen at one position only |
| `discard` of a block (hours to days) | A step to another level that never recurs and is much shorter than the rest of the stap; or a stretch with no consistent level at any plausible position | A block that only disagrees with ERA5 at one position |

**How to see the evidence.** Do not judge from summaries alone. For each stap you change, write a
static plot to a PNG and look at it (`plot_pressurepath(..., plot_plotly = FALSE)`, section 10),
and list the steps numerically (`tag_label_check(tag, warning_pressure_diff = 1.5)` lists hourly
jumps). If you cannot inspect a stap, leave it.

**The two-position test.** Before a label based on a residual, compute the residual at a clearly
different position: another distinct peak of the map, or a grid several degrees wide. A feature of
the bird (a step, a second level, a day cycle) appears at every plausible position and as abrupt
steps in the raw pressure. A feature that changes with the position is a position problem: change
the position (or the extent), not the labels. Two positions 50 km apart see almost the same
weather, so they do not test anything.

**Light as an independent check.** With light data, the light map does not depend on the pressure
labels, so it is the best outside witness of a position. For each long stap, compare the most
likely pressure position with the light map (`map_light` near the pressure peak, or the distance
between the two peaks). A pressure position that light rules out is suspect: check the position,
the extent and the calibration before changing pressure labels, and never discard pressure to make
it agree with light. Light is coarse (hundreds of km) and biased by shade, so use it to reject
positions, not to place them. When two label choices are both defensible from the raw pressure (for
example a short level kept as `elev_n` or discarded), prefer the one whose position light does not
rule out. Calibrate light on long staps too (Step 9); where light is low everywhere, it carries no
information.

**Change budget.** Outside flights, spikes and edge points:
- per round, change at most about 10 % of a stap's points, and only in staps with a sign of a
  problem;
- over all rounds, change at most about 20 % of a stap without the user's agreement;
- the tag's discard share should stay below about 15 % (there is no minimum: lowland birds often
  need almost none);
- a stap that seems to need more than half of its points relabelled has a position, extent, flight
  or sensor problem, not a labelling one.

Exceptions are named strategies of section 6 (night roost for commuting birds, the most common
level in mountain stays). Ask the user first. When they cannot be asked (a batch run), apply the
strategy only to the staps that need it, in its own round file, and name it in the report so the
user can reject it. These strategies routinely need 20–55 % discard; the budget does not apply to
them, but every other rule does.

**Signs of over-labelling.** Stop and reconsider when:
- the discard share grows in every round while the positions keep moving;
- your own discards brought a long stay (> 5 days) below about 0.3 hPa residual sd: you are probably
  trimming the weather mismatch of a wrong position;
- you created many short `elev_n` levels (under about 12 h each), or more than about three in a stap
  without a repeating pattern;
- two levels sit less than about 1 hPa apart (one level), or 1–2 hPa apart without abrupt steps
  in the raw pressure;
- you discarded where the raw pressure is smooth, only because the residual is large;
- level offsets drift with the weather instead of staying constant.

If positions move by more than a few pixels in two successive rounds while the discard grows, stop:
go back to the round whose positions agree best with light and give plausible flight speeds, and
report the stap as unresolved.

**Signs of under-labelling.** The guardrails are not a reason to leave clear errors. Look again
when:
- a long stay (weeks to months) has no discard at all: in real data it almost always has isolated
  spikes (the evidence table's definition) and often short bouts at another height (these count
  against the budget and need abrupt steps in the raw pressure);
- the stap's residual sd is below `sd` but `n_outlier > 0` or its residual plot still shows
  outliers or abrupt steps: a small sd over thousands of points hides them. Read the plot of every
  long stay (section 10), not only its sd;
- a long stay has no discarded twilight while `twilight_check()` flags several off the line;
- the starting labels came from someone else: re-check them and propose changes in a round file.

**Is the change worth it?** A change is worth making when it removes a clear error (spike, missed
flight, wrong level) or moves or sharpens the position of a stap that matters (long stays,
stopovers on the route). Clear errors (spikes, edge points, missed flights, wrong levels, twilight
outliers) are always fixed. Beyond them, stop when a change would only lower an sd and no longer
moves or sharpens any position, even if more could be labelled. Detailed work where it changes the track,
none where it does not.

**Leave it, and say so.** Labelling a stap is optional; explaining it is not. A short stap with a
weak map, a noisy stay without structure, or a doubtful feature is best left as it is and listed for
the user, with the evidence for and against.

## 4. Procedure

The order follows the human workflow (Manual `labelling-tracks`, Template `AGENTS.md`). Section 10
has the code.

### Step 0. Data that labels cannot fix

Settle these first; labels made before them are lost.

- **Aerial feeders: do not label.** Swallows, martins, swifts, bee-eaters and other birds that feed
  in flight move up and down all day, so their pressure has no stationary ground level and no
  clear flight boundaries. Do not label them, as an agent, unless the user explicitly asks; then
  only with extreme caution, every flight and level checked with the user, and the result reported
  as uncertain. Say so before starting, and stop rather than invent flights or discard most of the
  data to make a track.

- Crop to attachment–retrieval or logger failure (`crop_start`, `crop_end`): look at pressure,
  activity and light at both ends. Pre-attachment data ruin the mask.
- Clock: `time_shift`, `time_drift`. A wrong clock shifts twilights and flights. Twilights that
  step away from the expected ones at a known site mean a logger that paused: read
  `references/clock.md`.
- Pressure: sampling of 1 h or less; plausible values; no flat stretches (dead sensor); data gaps
  noted; no offset or slow drift visible as an impossible altitude (check
  `pressurepath$altitude` later).
- `extent` large enough and `known` correct. A wrong extent or known site gives a wrong track
  without an error, and looks like a labelling problem.

### Step 1. Flights

With acceleration (activity):

- Start from `tag_label_auto()`. Published labellers kept most of its flights, deleted many, merged
  others and extended ends.
- Review each flight:
  - **Merge fragments**: low activity inside a flight (gliding, the end-of-night descent) is still
    flight when activity resumes and pressure keeps changing. Fragments create short staps.
  - **Flight ends**: with 5-min data, the end is often 5–50 min later than the automatic one, when
    pressure returns to a stable ground level. With hourly data, partly active hours at both ends
    are usually trimmed instead.
  - **Delete non-migratory bouts**: activity with no lasting pressure change and no new ground level
    after it (foraging, display, Arctic summer).
  - **Add short relocation flights**: a short burst (even 10–30 min) with a pressure change and a new
    ground level after it. A burst whose pressure returns to the same level is a local move: no
    flight; discard its pressure points if they are off-level.
  - The time of day is not a criterion: many species (bee-eaters, swifts, hirundines, raptors)
    migrate by day.
- Short halts between flights are a new stap only if the bird probably changed place (another level
  before and after, or a landing pattern). When undecided, keep the stap and let the map and the
  ERA5 comparison decide.

Without acceleration (pressure only): label `flight` where pressure leaves the ground level quickly
and settles at a new level, including the descent and climb samples. Weather changes are slow (a
few hPa per day) and shared with ERA5.

Then `tag_label_check(tag)` lists staps ≤ 6 h, flights ≤ 2 h and hourly jumps ≥ 3 hPa (TRAINSET's
Check button). Fix or explain each item.

### Step 2. First pressure pass, without a position

Only what is clear in the raw data, within the budget of section 3.1:

- Points still descending or climbing at the start or end of a stap: extend the flight, or discard
  them.
- Spikes (evidence table, section 3.1).
- A jump > 20 hPa inside a stap that does not come back: a missed flight if activity or a new
  ground level supports it. A jump that comes back is a spike, an excursion or an elevation level
  (mountain and commuting birds move 10–100 hPa daily).
- A short, one-off excursion to another level: discard it. Longer or recurring levels wait for a
  position (steps 5–6).

### Step 3. Coarse maps

Rebuild the tag from the labels (a tag that went through `tag_set_map()` cannot be relabelled) and
compute maps with the project's settings, only a coarser `scale` (1–2) and a lower `max_sample`
(50–100). Then read `tag$map_pressure$stapelev`:
- a level with `n_valid == 0` fits no pixel; a best-pixel sd, `sqrt(mse_min)`, several times `sd`
  fits nowhere well. Both point to a labelling, extent or known-site problem (section 2.3).
  `mse_min` comes from smoothed hourly data, so it is lower than the residual sd of step 5: compare
  it with `sd` and with other staps, not with `pressurepath_check()`;
- a long stap whose best pixel lies on the extent border suggests the extent is too small.
Fix these before going on.

### Step 4. Positions

Take the position of each stap from the map with `tag2path(tag)`. Note that
`tag2path(tag, interp = 1)` replaces the positions of staps shorter than a day by interpolation:
fine for a first trajectory, but such a stap has no position of its own, so do not label it from
its residual. Check plausibility:

- Each position reachable in the flight time (`stap2flight()`; a small passerine rarely exceeds
  60–80 km/h ground speed).
- **Cumulative flight time matches the distance.** For each migration leg (between long stays,
  e.g. breeding to wintering), sum the labelled flight hours and compare with the distance (code in
  section 10; the great-circle distance between the two long stays is a lower bound, the distance
  along the path an upper one). The **mean** ground speed of the leg should be plausible for the
  species (small passerines about 30–60 km/h). Below about 20 km/h, some "flights" are local
  movements (activity bouts with a pressure change but no new place): check them before trusting
  the positions. Above about 70–80 km/h, flights are missed or truncated. Look at the leg total, not single flights: the speed of one short
  flight between two weak short-stap positions is noise.
- Light and pressure maps agree.
- Short staps (< 1 day) have weak, flat maps and uncertain positions: their residuals say little.

A user can draw a better path in `geopressureviz(tag)`; `read_stap()` reads its export.

### Step 5. Residuals at the position

Compute the residuals at the position (`pressurepath_create()` for all staps,
`geopressure_timeseries()` for one) and read `pressurepath_check()`. A stapelev needs a closer look
when `sd_exceeded` is TRUE, `error_sd` is clearly higher than in the tag's other staps, or
`n_outlier > 0` in a stay longer than a few days (published
long stays: median about 0.6 hPa, 90 % below 1.2 hPa). Look at its residual and at the plot
(section 10) for these signs:

| Sign | Likely cause | Action, within section 3.1 |
|---|---|---|
| Daily means swinging by several hPa, no day cycle, no step | Wrong position | Test other positions; do not label |
| A lasting shift of the 2–3 day rolling mean, at both positions | Level change partway through the stay | Split into levels by period (`elev_n`), or discard the shorter period |
| A jump > 20 hPa that does not come back, with activity | Missed flight | Fix the flight labels |
| Two modes, or day − night > 1 hPa, in a stay ≥ 1 day | Two heights | Look; `elev_n` only if the levels are ≥ 1 hPa apart with abrupt steps in the raw pressure, or discard the shorter / less consistent one |
| First or last points of the stap far off | Descent or climb left in | Extend the flight, or discard them |
| A few points off (`n_outlier`, evidence table) | Spikes | Discard those points |
| Nothing specific | Noise, or a short stap with a weak position | Leave it, and say so |

Example: Marsh Warbler DB231, a 95-day wintering stay. At the map's best pixel (29.9° S, 30.4° E) the
residual sd was 3.4 hPa, with daily means swinging ±3–8 hPa and no day cycle. Discarding half of the
points would have "fixed" it. A grid of positions showed the sd falling steadily south-west, to
0.86 hPa near 33–34° S: the project extent stopped at 30° S, so the true site was outside the map.

### Step 6. Automatic stapelev: a proposal, used sparingly

`tag_label_stapelev(tag, stap_id, lat, lon)` runs TRAINSET's "Automatic stapelev" on one stap and
returns the relabelled tag: residual = tag − raw ERA5 at the position; each level is a band of
± `range` hPa around an offset; points in no band become `discard`; runs shorter than `continuity`
hours are dropped. It works on a tag before `tag_set_map()`.

It is the strongest tool and the easiest way to over-label: it relabels every non-flight point of
the stap, manual discards included, discards everything outside its bands, and trusts the position
completely. Treat its output as a proposal to read.

Use it only when all of these hold:
- the stap shows two levels or a day cycle at a position that passed the two-position test and did
  not move between the last two rounds;
- the stap lasts at least a day, better two;
- the second level is visible as abrupt steps in the raw pressure.

Never run it over all staps at once, and never only because the sd is high.

Settings:
- Start with one level, `range = 2`, `continuity = 6`. If about 90 % of the points fit one level,
  keep the old labels.
- Add a level (`n_level = 2`, rarely 3) only when the second band holds at least 5–10 % of the
  points and recurs. An error about not enough unexplained pressure means fewer levels.
- `discard_solar = "day"` keeps the night roost of a commuting bird: an exception of section 3.1,
  only with the user's agreement.
- `range` must exceed the noise: at least the sensor resolution (SOI loggers: 1 hPa) plus the
  remaining day cycle. With 1 hPa data and a day cycle, use 3 or more. Narrow it only in a later
  round at a confirmed position. Never `continuity = 0`.
- If the proposal is rejected for a commuting bird, use the night-roost scan of section 10
  instead.

Compare the old and new labels (section 10), and reject or trim the proposal when:
- any sign of over-labelling of section 3.1 appears, or it exceeds the budget;
- it drops points that look smooth in the raw pressure (restore them);
- the residual within a new level still has a trend or a day cycle.

Report what you kept and what you rejected, with these numbers.

### Step 7. Rebuild and iterate

Write the labels to a new round file (section 9), rebuild the tag, recompute maps, positions and
residuals. A stap that moved more than its map resolution needs its residuals recomputed before more
labelling. Two to four rounds is usual; later rounds are narrow fixes.

### Step 8. Stop when

- Every item of `tag_label_check()` is fixed or explained; no level with `n_valid == 0`; no
  best-pixel sd several times `sd`.
- Every stapelev that stands out in `pressurepath_check()` is resolved or explained.
- The guardrails of section 3.1 hold.
- Positions no longer move between rounds, and flight speeds are plausible.

These are conditions, not targets; when they hold, apply "Is the change worth it?" (section 3.1).

### Step 9. Twilights (if light was recorded)

- Create the twilights with the project's settings and check that nights are centred
  (`plot(tag, type = "twilight")`; twilights at midnight mean a wrong `twl_offset`).
- Discard a twilight that is off the smooth line of its neighbours within a stap (and, with a
  path, `outside_ci`). Keep `outside_ci` twilights that sit on the line: the position or the
  calibration is wrong instead. With a calibration and a
  path, `twilight_check()` marks twilights outside the calibrated range (`outside_ci`): look at
  them, do not discard them all. Published discards are typically 2.5–8 % of twilights, 15–30 % for
  shaded, cavity or Arctic species.
- Do not over-edit calibration staps: their scatter is the twilight error model.
- When light contradicts a well-supported pressure position, first check that stay's twilights
  (`plot(tag, type = "twilight")` over the stay; outliers left in shift the light map) and the
  calibration, then say so to the user; discarding a whole period is their decision.
- Calibrate with long staps too, not only the known sites: known sites are often short, at the
  breeding site, or in mountains. `geolight_map(fitted_location_duration = )` (e.g. 20–30 days)
  adds every long stap to the calibration and usually widens a too-strict light model.
- Light maps of long stays are often too narrow: the calibration error is systematic and does not
  shrink with the number of twilights, while `twl_llp` still sharpens the map with `n`. When a long
  stay's light map is narrower than about 2–3°, or light and pressure disagree by more than its
  width, say so and suggest a smaller `twl_llp` (e.g. `\(n) 0.5 * log(n) / n`) or a larger
  `twl_calib_adjust` (the user's choice).

### Step 10. Final checks

- `sd` is the user's choice (published: 0.5–2; larger for birds moving up and down).
- Before judging how wide the maps are, read the pooling weights in the config:
  `log_linear_pooling_weight` (pressure) and `twl_llp` (light), both `\(n) log(n)/n` by default. A
  weight four times the default makes the pressure map as narrow as `sd` halved. If they differ from the default, report it; the
  setting is the user's choice.
- After the full model, read `pressurepath_check()` on `pressurepath_most_likely` and the flight
  speeds in `edge_most_likely`.
- If flights changed after `tag_download_wind()`, the wind files must be downloaded again.

## 5. Decision rules

All within the guardrails of section 3.1.

| Situation | Signal | Action |
|---|---|---|
| Isolated spike | Evidence table, section 3.1 | `discard` |
| Point at a stap edge off the level | first/last points far from the stap's level | Extend the flight, or `discard` |
| Missed flight | A level change after a burst of activity, or a large jump that does not come back | Label the flight; the stap splits |
| Temporary excursion that returns | Step of > 2–3 hPa for minutes to hours, then back | `discard` the excursion, or `elev_n` if it recurs |
| Recurring second height | Second mode ≥ 1 hPa away with abrupt raw steps (≥ 2 hPa otherwise), ≥ 5–10 % of points, in a stay ≥ 1 day | `elev_n` |
| Day/night alternation | \|day − night\| > 1 hPa in a stay ≥ 1 day | Look; two levels if ≥ 1 hPa apart with abrupt raw steps, or (agreed strategy) discard daylight and keep the night roost. Above 2 hPa it is almost never noise |
| One-off height change that never returns | Another level before and after, no flight seen | A new stap (if activity supports a flight) or discard the shorter part |
| Short level | A level under about 12 h with few points | Discard rather than `elev_n`, unless it is a clean highest or lowest level |
| Slow drift in a long stay | Rolling mean of the residual moves > 2 hPa over weeks, at every plausible position | Split into levels by period, or discard the drifting part |
| Noisy sensor | High sd at every plausible position, no structure | A larger `sd` (user's choice); do not discard to compensate |
| Off-terrain resting altitude | `pressurepath$altitude` outside the ground range | Not a labelling issue: position, `margin`, sensor offset |
| Weather-scale mismatch | Daily means swing several hPa, no day cycle, and no lasting step in the 2–3 day rolling mean | Not a labelling issue: other positions, the extent |
| Known-position stap | Large sd at the known site | Label it only if altitude or the pressurepath is a product; it does not change the map |

## 6. Hard cases

Each strategy here that exceeds the change budget needs the user's agreement first (section 3.1).

- **Lowland reed and marsh birds**: published discard often well under 1 %; most work is at flight
  edges.
- **Mountain, rocky-ground and Arctic species**: published discard 15–55 %, many levels. Find the
  most common level, keep it, then add levels that recur. Keep the highest and lowest clean levels.
  Daily jumps of tens of hPa are movements, not flights. A larger `margin` and `sd` may suit (user's
  choice).
- **Commuting between roost and foraging site** (starlings, ring ouzels, hoopoes): day and night
  levels, or discard daylight (published starlings: 85 % of day points discarded, 5 % at night).
- **No consistent level in a long stay** (ring ouzel winters): every point of a stap cannot be
  discarded (`geopressure_map()` stops). Keep the largest consistent block, often the night roost,
  and tell the user the position rests mostly on the mask.
- **Long stays with slow shifts or sensor drift**: scan the residual in windows of a few days;
  split by period when shifts exceed about 2 hPa at every plausible position.
- **Hourly data**: smoother residuals, but each flight end matters by an hour.
- **1–5 min data**: noisier residuals per level; judge on residuals, not point counts.
- **Pressure only, no activity**: flights from pressure (step 1); short stops are hard to tell from
  weather, so compare with ERA5 before splitting.
- **Short staps (< 1 day, most staps)**: low sd, uncertain positions. Check that they are real stops
  and not a flight tail; otherwise leave them.
- **Birds on water or the coast**: water pixels are excluded, so maps can look empty or squeezed to
  the shore. Not a labelling problem.
- **Data gaps**: a gap inside a stap is not a flight unless activity or pressure says so.
- **Unusable pressure** (faulty sensor): the user may keep the tag for flight timing only.

## 7. Published examples

As published in the GeoLocator Data Packages v1.3 (November 2026); packages can be relabelled
later. Use them to calibrate judgement, not as targets.

Long stays that needed little labelling: Red-backed Shrike X0AD stap 10 (2018-08-08 → 08-26);
Marsh Warbler CS338 stap 16 (2024-07-29 → 08-10).

| Failure | Example |
|---|---|
| Pressure never labelled | Eurasian Hoopoes Germany 34BM, 34KB: day/night shifts of 15–19 hPa |
| Unlabelled second level | Hoopoes Germany 34BM stap 30 (2024-10-24 → 2025-03-11): 15 hPa split |
| Commuting left in | Common Starlings Latvia 28TG stap 8 (2022-11-13 → 2023-02-06): +15.5 hPa by day |
| Mixed levels inside an `elev` group | MIGRATLANE CM414 stap 2 `elev_1`: 17.7 hPa split |
| Unlabelled flight inside a stap | Hoopoes Germany 34BK stap 13 (2024-09-10) |
| Landing descent kept, ground points discarded | Swiss Hoopoes 16AO (fixed 2025-08) |
| Site outside the extent | Marsh Warbler DB231 (step 5) |

## 8. Pitfalls

1. **Over- and under-labelling** (section 3.1).
2. **Off-by-one at flight boundaries**: check the first and last pressure points of every stap.
3. **Fragmented flights** and **non-migratory bouts labelled as flight**: many short staps.
4. **Real flights deleted** because they happen by day.
5. **Flip-flopping** between rounds on ambiguous flights: write down the rule used and keep it.
6. **`flight` on pressure when acceleration is labelled**: ignored for staps, confusing in files.
7. **Trainset and GeoLightViz Save write `<id>-labeled.csv`**, and `trainset(tag)` on an unlabelled
   tag restarts from automatic labels (section 9 for agent rounds).
8. **Relabelling after crop or clock changes**: the timestamps change; rebuild from `tag_create()`.

## 9. Working with the user

Labels are the user's decisions, and the label files are their data. The Template's rules apply:
the user labels, and a label file is edited only with their agreement.

- **Agree on the scope first**: which tags, which steps, what you may change.
- **Never overwrite `<id>-labeled.csv`.** Write each round to a new file,
  `data/tag-label/<id>-agent-r<k>-labeled.csv`, and read it with `tag_label(tag, file = ...)`. The
  user reviews it with `trainset("data/tag-label/<id>-agent-r<k>-labeled.csv")`: Trainset takes the
  id from the file name, so Save writes back to that file. Once the user accepts a round, they copy
  it to `<id>-labeled.csv` (suggest committing the previous version first). `trainset(id)` is for
  the user's own labelling.
- **Twilights**: write proposals with `twilight_label_write(tag, file = ...)` to a round file and
  list them. GeoLightViz Save writes `<id>-labeled.csv`, so reviewing there means accepting.
- **Go in stages.** Labels that need no position (flights, spikes, edges) can be proposed for the
  whole tag. Labels that depend on a position (`elev_n`, block discards, automatic stapelev) go only
  to staps with a sign of a problem, and the user reviews every such round before the next.
- **Report every change**: the changed runs (start, end, points, old and new label; section 10),
  the reason and the evidence (plot, raw step, residuals at two positions, activity), the stap's
  position before and after, and the discard share per stap and per tag before and after.
- **Report what you did not change** and why: the doubtful cases are the user's to decide.
- Do not change `sd`, `margin`, `thr_mask`, `extent` or `known` to make labels look better; propose
  them separately with reasons.

### 9.1 How the user reviews the result

An agent's labels are a proposal until the user has looked at them. At the end, give the user this
review, filled in for their tag (stap ids, dates and what to look at), and wait for their answer
before anything is copied to `<id>-labeled.csv`. Run it after the full model
(`geopressuretemplate(id)` or the Template's scripts), from the project root:

```r
id <- "<id>"
load(glue::glue("data/interim/{id}.RData"))   # tag, path_most_likely, pressurepath_most_likely, ...

# 1. The trajectory: positions, flight durations and speeds, each stap's pressure against ERA5.
#    Move a stap on the map to see whether its pressure fits better elsewhere.
geopressureviz(id)

# 2. Pressure: residual of every stap along the most likely path (outliers, steps, day cycles)
plot_pressurepath(pressurepath_most_likely)
plot_pressurepath(pressurepath_most_likely, type = "hist")   # error sd per stap against sd

# 3. Light: twilights with the times expected along the path, and the calibration
plot(tag, type = "twilight", twilight_line = path2twilight(path_most_likely))
plot_twl_calib(tag, path_most_likely)

# 4. Edit, if needed, in the round file (Save writes back to it)
trainset(glue::glue("data/tag-label/{id}-agent-r2-labeled.csv"))
```

What to ask the user to look at:
- **GeoPressureViz**: the staps you changed or flagged; flight speeds that look too fast or too
  slow; short staps far off the route; positions that light does not support.
- **Pressure plots**: long stays with spikes or steps left in, and levels you added (do they hold
  for the whole period?).
- **Twilight plots**: twilights off the expected line in long stays (discard or keep?), and
  whether the line follows the twilights at each long stay. A systematic offset at one stay is a
  position or calibration problem, not a twilight label.
- **Your list of open decisions**: each with the two options and what each does to the track.

Then apply the user's feedback in a new round, rerun, and give the same review again for the
staps that changed.

## 10. Recipes

GeoPressureR (>= 3.9.1) only. In a Template project, use the project's settings so that the checks
match the final run.

```r
id <- "18LX"
cfg <- geopressuretemplate_config(id)
build <- \(file) do.call(tag_create, c(list(id = id), cfg$tag_create)) |> tag_label(file = file)
set_map <- \(t) do.call(tag_set_map, c(list(t), modifyList(cfg$tag_set_map, list(scale = 1))))
sd <- cfg$geopressure_map$sd
tag <- build(glue::glue("data/tag-label/{id}-labeled.csv"))

# Steps 1-2: TRAINSET's checks; a lower threshold lists smaller steps
tag_label_check(tag)
tag_label_check(tag, warning_pressure_diff = 1.5)$pressure

# Step 3: coarse maps with the project's map settings
tag_m <- do.call(geopressure_map, c(list(set_map(tag)), modifyList(cfg$geopressure_map, list(max_sample = 100))))
tb <- tag_m$map_pressure$stapelev          # n_valid == 0: fits no pixel
tb$best_sd <- sqrt(tb$mse_min)

# Step 4: positions from the map (no interpolation), one row per stap
path <- tag2path(tag_m)

# Step 5: residuals along the path, then one stap at a time
pp <- pressurepath_create(tag, path)
pressurepath_check(pp, sd = sd)
s <- 5  # a stap flagged by pressurepath_check() (18LX has 5 staps)
p_s <- path[path$stap_id == s, ]
ts <- geopressure_timeseries(p_s$lat, p_s$lon, pressure = tag$pressure[tag$pressure$stap_id == s, ])
pressurepath_check(ts, sd = sd)            # repeat at a clearly different position
e <- ts$pressure_tag - ts$surface_pressure_norm
ok <- ts$label != "discard"
tapply(e[ok], as.Date(ts$date[ok]), mean)       # daily means: weather-scale swings?
tapply(e[ok], format(ts$date[ok], "%H"), mean)  # by hour: a day cycle?
g <- plot_pressurepath(ts, sd = sd, plot_plotly = FALSE)
ggplot2::ggsave(glue::glue("label-check-{id}-{s}.png"), g, width = 10, height = 4)  # then look at it

# Position-free level scan: deviation from a rolling reference of the night points of a stap
# (night roost of commuting birds, the most common level of mountain stays)
p <- tag$pressure[tag$pressure$stap_id == s, ]
night <- suntools::solarpos(cbind(p_s$lon, p_s$lat), p$date)[, 2] < -6  # a rough position is enough
k <- 2 * floor(sum(night) / as.numeric(diff(range(p$date)), units = "days")) + 1  # about 2 nights
ref <- stats::approx(p$date[night], stats::runmed(p$value[night], k), p$date, rule = 2)$y
table(cut(p$value - ref, c(-Inf, -4, 4, Inf)))  # within ±3-4 hPa: the roost level; plot it too

# Step 6: automatic stapelev for one stap that meets the conditions (returns the tag)
new <- tag_label_stapelev(tag, s, p_s$lat, p_s$lon, timeseries = ts)

# Changed runs between two label sets (the review and the change log); NULL if none
old <- tag$pressure$label
lab <- new$pressure$label
ch <- old != lab
run <- cumsum(c(TRUE, diff(ch) != 0 | old[-1] != old[-length(old)] | lab[-1] != lab[-length(lab)]))
do.call(rbind, lapply(split(which(ch), run[ch]), \(i) data.frame(
  start = min(tag$pressure$date[i]), end = max(tag$pressure$date[i]), n = length(i),
  from = old[i[1]], to = lab[i[1]]
)))
ground <- tag$pressure$stap_id %% 1 == 0             # ground points only
round(100 * tapply(lab[ground] == "discard", tag$pressure$stap_id[ground], mean), 1)  # discard % per stap

# Residual plot of every stay longer than 5 days (look at each; sd alone hides spikes and steps)
for (s in tag$stap$stap_id[stap2duration(tag$stap) > 5]) {
  g <- plot_pressurepath(pp[pp$stap_id == s, ], sd = sd, plot_plotly = FALSE)
  ggplot2::ggsave(glue::glue("label-check-{id}-{s}.png"), g, width = 10, height = 4)
}

# Step 4: mean ground speed per leg, between the two longest stays (e.g. breeding and wintering)
path$j <- 1                                            # path2edge() needs a j column
ed <- path2edge(path, tag_m)                          # needs a tag with a map
long <- sort(order(stap2duration(tag$stap), decreasing = TRUE)[1:2])
leg <- ed$stap_s >= long[1] & ed$stap_t <= long[2]
sum(ed$distance[leg]) / sum(as.numeric(ed$duration[leg], units = "hours"))  # km/h

# Write the round to a new file, rebuild, loop to step 3
f <- glue::glue("data/tag-label/{id}-agent-r1-labeled.csv")
tag_label_write(new, file = f)
tag <- build(f)

# Step 9: twilights with the project's settings, checked against the path
tag_t <- do.call(twilight_create, c(list(tag), cfg$twilight_create)) |>
  twilight_label_read(file = glue::glue("data/twilight-label/{id}-labeled.csv"))
tag_t <- do.call(geolight_map, c(list(set_map(tag_t)), cfg$geolight_map))
tw <- twilight_check(tag_t, path)
tw[which(tw$outside_ci & tw$include), ]
```

Notes:

- Edit labels directly in `tag$pressure$label` or `tag$acceleration$label`, then write the round.
  `tag_label_write()` writes pressure and acceleration; `twilight_label_write()` writes twilights.
- `geopressure_map()` takes minutes per tag: run it in the background for many tags.

## 11. Where no rule exists

The Manual and practice leave these open. Do not invent a rule: state the options, take the most
conservative one (keep the point, keep the stap), and ask the user.

- The exact flight end (last active sample, return to ground pressure, or fixed padding).
- When a short halt or a short burst is a new stap.
- The minimum length of an `elev_n` level: this guide uses about 12 h, a convention (practice:
  often 6 h; the Manual suggests 12–24 h).
- What to keep in a stay with no consistent level.
- `sd` per stap (supported by `geopressure_map_likelihood()`, not by the Template config).
- Twilight calibration beyond Step 9 (`twl_calib_adjust`, `twl_llp`).
- Which to trust when light and pressure disagree.
