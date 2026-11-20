# Clock errors: guide for agents

How to find and correct a wrong logger clock before labelling. Written for GeoPressureR 3.9.1; the
recipe uses its exported functions and base R. Correcting the clock changes the data the whole
analysis rests on: the user decides, and every correction is recorded (section 6).

## 1. Kinds of error

| Error | Signature at a known or resident site | Fix |
|---|---|---|
| Constant offset (clock set to local time, wrong time zone) | Twilights early or late by the same amount from the start | `time_shift` (hours) |
| Linear drift (clock fast or slow) | Offset grows steadily. SOI: `tag$param$tag_create$settings$clock_drift` | `time_drift` (hours per year), `time_reference` at `StarttimeRTC` (see `?tag_create`) |
| Steps (logger paused while its timestamps kept counting) | Offset flat for days, then jumps, always to earlier recorded times | Piecewise shift (section 5): `tag_create()` has none in 3.9.1 |

SOI timestamps behave as if rebuilt from the logging start and the number of samples (inferred
from the data, not documented by SOI). If the logger stops sampling for a while, every later
sample of every sensor is dated too early by the length of the pause, and the sampling interval
still looks constant. Seen on SOI GDL3pam firmware V2.6.0-RC1.

## 2. Signs of steps

- At a known or resident site, the light image (`plot_tag_twilight()` with the twilights expected
  at the site from `path2twilight()` as `twilight_line`) steps away from the lines; sunrise and
  sunset move together, by the same amount.
- The offset only grows, often in clusters of steps over a few days. It can reach many hours.
- All sensors move together: the actogram, the daily temperature cycle and the pressure tide follow
  the light.
- `*.settings`: `StopTimeRTC` reset (e.g. `01.01.2000 00:00:00`), `RecordingStop` "timestamp
  invalid", or a `clock_drift` of days (the "suspicious" warning of `tag_create()`); data ending
  long before retrieval.
- Decoder gaps (`-2` rows, read as `NA`) are more frequent near steps, but do not mark them.
- A constant sampling interval does not rule steps out.

## 3. Clock step, movement or shading

- **Clock step**: abrupt, both twilights shift by the same amount, persists, no flight.
- **Longitude change**: the same twilight signature (4 min per degree), but after a flight. Light
  cannot tell the two apart. A step whose interval overlaps a flight (`tag_label_auto()`) and is
  no larger than a plausible move is movement unless other evidence says otherwise: list it and ask.
- **Latitude change or season**: sunrise and sunset move in opposite directions (day length).
- **Shading**: one twilight off, on a few days, no lasting level.
- **Direction**: pauses only lose time. An apparent jump forward of x h is a loss of 24 − x h.
- **Whole days** lost are invisible in light. Check the total against a dated event (retrieval,
  end of recording, a known departure) and tell the user what it rests on.
- **Placement**: twilights place a step only between two twilights (about 12 h). Steps on
  successive days look like a ramp; what matters is the offset at each twilight, not the number
  of steps.

## 4. Procedure

1. Build the tag without clock correction, cropped in recorded time to the period on the bird,
   without the attachment day.
2. Estimate the offset at the site (recipe): the daily light phase gives a coarse offset that
   survives jumps of many hours; the twilights of the coarsely corrected tag refine it to 5 min.
3. Show the user the offset plot and the step table (interval, size, overlapping flight). The user
   decides which steps to correct.
4. Apply (section 5), rebuild the tag and validate:
   - Twilight residuals at the site centred on 0 (median of the sunrise–sunset midpoint within
     about 5 min), with no level shift left. Away from the site only flight-related changes remain.
   - Actogram: activity by day, rest at night, no jump at the steps.
   - Pressure tide against ERA5 at the site (one `geopressure_timeseries()` call): per 10-day
     window, the lag that best correlates the detrended hourly tag and ERA5 pressure is 0 h.
   - The daily temperature cycle keeps its phase relative to light (a sensor-specific error would
     show here).
5. Label only after this: labels and TRAINSET files made before are tied to the old timestamps.

## 5. Applying a piecewise correction

- **Corrected copies of the raw files** (works with the Template today). Keep the originals
  unchanged. Write copies in which only the timestamps change, to a separate folder, and point
  the tag to it in `config.yml` (`tag_create: directory:`). Keep the step table (CSV) and the script
  next to them. Do not add rows to fill the pauses: zero rows read as darkness, 0 °C and rest, and
  in 6-hourly magnetic data as false measurements. `tag_create()` reads the gaps as irregular
  spacing, which is correct.
- **In code on the `tag`** (`correct()` below): fine to explore, but `geopressuretemplate_tag()`
  rebuilds the tag from `config.yml`, so the correction would be lost.
- If a later GeoPressureR accepts a step table in `time_shift`, use it instead (check
  `?tag_create` and NEWS).

## 6. Provenance

A clock correction of raw data is a change of data provenance. Ask before writing any corrected
file, and never overwrite the originals. Record in the tag's `tag_comment` in `config.yml` the
method, the number of steps and the total shift, the step-table file, who decided it and when, and
what the total rests on. Say so when the data are published.

## 7. Recipe

GeoPressureR (>= 3.9.1). Set the known site and the crop; the light threshold `> 0` is the night
level of SOI raw counts (use the twilight threshold for other loggers).

```r
id <- "18LX"; lon <- 17.05; lat <- 48.9                 # tag and its known (or resident) site
raw <- tag_create(id, crop_start = "2017-07-28", crop_end = "2018-05-01")  # on the bird, no correction

# Step table `b`: from recorded time `date` on, add `shift` hours to every sensor
shift_at <- \(d, b) c(0, cumsum(b$shift))[findInterval(as.numeric(d), as.numeric(b$date)) + 1]
correct <- \(tag, b) {
  for (s in intersect(names(tag), c("pressure", "light", "acceleration", "temperature_external",
                                    "temperature_internal", "magnetic"))) {
    tag[[s]]$date <- tag[[s]]$date + round(shift_at(tag[[s]]$date, b) * 60) * 60
  }
  tag
}
# Non-increasing step fit (pauses only lose time), on the 5-min grid, steps >= 10 min
steps <- \(date, off) {
  date <- date[!is.na(off)]
  off <- off[!is.na(off)]
  f <- round(-stats::isoreg(-stats::runmed(off, 3))$yf * 12) / 12
  i <- which(abs(diff(f)) > 9 / 60)
  cum <- -c(round(median(off[1:10]) * 12) / 12, f[i + 1])  # at the start, then after each step
  b <- data.frame(date = c(date[1] - 86400, date[i] + (date[i + 1] - date[i]) / 2),
                  shift = diff(c(0, cum)), from = c(date[1] - 86400, date[i]), to = c(date[1], date[i + 1]))
  b[b$shift != 0, ]
}

# 1. Coarse: daily light phase minus solar noon at the site (h), unwrapped
m <- ts2mat(raw$light, twl_offset = 0)
l <- m$value > 0
a <- 2 * pi * (seq_len(nrow(l)) - 0.5) / nrow(l)
day <- as.POSIXct(m$day, tz = "UTC") + 43200
sun <- path2twilight(data.frame(lon = lon, lat = lat, date = day, stap_id = 1), return_long = FALSE)
noon <- as.numeric(sun$sunrise + (sun$sunset - sun$sunrise) / 2) %% 86400 / 3600
off <- atan2(colSums(l * sin(a), na.rm = TRUE), colSums(l * cos(a), na.rm = TRUE)) * 12 / pi - noon
off[colMeans(is.na(l)) > 0.2 | abs(colMeans(l, na.rm = TRUE) - 0.5) > 0.3] <- NA  # gaps, odd days
w <- (off[!is.na(off)] + 12) %% 24 - 12
off[!is.na(off)] <- w[1] + cumsum(c(0, (diff(w) + 22) %% 24 - 22))  # a rise > 2 h: loss of 24 h minus it
b1 <- steps(day, off)

# 2. Fine: twilights of the coarsely corrected tag against the site, back in recorded time
tw <- twilight_create(correct(raw, b1))$twilight
ex <- path2twilight(data.frame(stap_id = 1, lon = lon, lat = lat,
  start = min(tw$twilight) - 86400, end = max(tw$twilight) + 86400))
r <- vapply(seq_len(nrow(tw)), \(i) {
  x <- as.numeric(tw$twilight[i] - ex$twilight[ex$rise == tw$rise[i]], units = "hours")
  x[which.min(abs(x))]
}, 1)
cc <- c(0, cumsum(b1$shift))
k <- findInterval(as.numeric(tw$twilight), as.numeric(b1$date) + cc[-1] * 3600) + 1
bias <- (median(r[tw$rise]) - median(r[!tw$rise])) / 2  # threshold: sunrise late, sunset early
tw$rec <- tw$twilight - cc[k] * 3600
tw$off <- ifelse(abs(r) > 3, NA, r - ifelse(tw$rise, bias, -bias) - cc[k])
b2 <- steps(tw$rec, tw$off)

# 3. Review with the user: offsets, steps, and steps that overlap a flight
plot(tw$rec, tw$off, pch = 16, cex = 0.5, col = ifelse(tw$rise, "orange", "purple"),
  xlab = "Recorded time", ylab = "Clock offset (h)")
lines(c(min(tw$rec), b2$date), -c(0, cumsum(b2$shift)), type = "s")
fl <- tag_label_auto(raw)$acceleration
b2$flight <- vapply(seq_len(nrow(b2)), \(i) {
  any(fl$label[fl$date >= b2$from[i] & fl$date <= b2$to[i]] == "flight")
}, TRUE)
b2

# 4. Validate on the corrected tag
tag <- correct(raw, b2) |> twilight_create()
site <- data.frame(stap_id = 1, lon = lon, lat = lat, start = min(tag$light$date), end = max(tag$light$date))
plot_tag_twilight(tag, twilight_line = path2twilight(site))
plot_tag_actogram(tag, double_plot = TRUE)

# 5. Once the user agrees: corrected copies, only the timestamps change (6 header lines in SOI files)
from <- glue::glue("data/raw-tag/{id}")
to <- glue::glue("data/raw-tag/{id}-clock")
dir.create(to)
for (f in list.files(from, "\\.(pressure|glf|acceleration|airtemperature|temperature|bodytemperature|magnetic)$",
                     full.names = TRUE, ignore.case = TRUE)) {
  x <- readLines(f)
  i <- 7:length(x)
  t <- as.POSIXct(substr(x[i], 1, 16), format = "%d.%m.%Y %H:%M", tz = "UTC")
  x[i] <- paste0(format(t + round(shift_at(t, b2) * 60) * 60, "%d.%m.%Y %H:%M"), substring(x[i], 17))
  writeLines(x, file.path(to, basename(f)))
}
file.copy(list.files(from, "\\.settings$", full.names = TRUE), to)
write.csv(b2, file.path(to, glue::glue("{id}-clock-steps.csv")), row.names = FALSE)
```

Notes:

- The step table is in recorded time; `shift` is the time added at each step, in hours.
- A step of more than 12 h, or several steps between two valid days, can be misread by a multiple
  of 24 h: compare the total with the dated anchor (section 3).
- The crop of the final tag applies to corrected times: check `crop_start` and `crop_end` again.
