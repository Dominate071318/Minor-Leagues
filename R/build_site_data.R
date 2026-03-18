# R/build_site_data.R — convert processed CSVs → JSON for the static website
library(tidyverse); library(jsonlite)

PROC     <- "data/processed"
SITE_DIR <- "docs/data"
dir.create(SITE_DIR, recursive = TRUE, showWarnings = FALSE)

read_proc <- function(name) {
  path <- file.path(PROC, paste0(name, ".csv"))
  if (!file.exists(path)) return(NULL)
  read_csv(path, show_col_types = FALSE)
}

to_json <- function(df, name, ...) {
  if (is.null(df) || nrow(df) == 0) return(invisible(NULL))
  json <- toJSON(df, na = "null", ...)
  write(json, file.path(SITE_DIR, paste0(name, ".json")))
  message(sprintf("  [JSON] %s.json", name))
}

# ── Per-level batting leaderboards ───────────────────────────────────────────
batting  <- read_proc("batting")
pitching <- read_proc("pitching")
fg_bat   <- read_proc("fg_batting")
fg_pit   <- read_proc("fg_pitching")

# Combined batting (MLB API + FG merged on player name + level where possible)
if (!is.null(batting)) {
  batting %>%
    group_by(level) %>%
    group_walk(~to_json(.x %>% head(200), paste0("batting_", tolower(.y$level))))
  to_json(batting %>% head(500), "batting_all")
}
if (!is.null(pitching)) {
  pitching %>%
    group_by(level) %>%
    group_walk(~to_json(.x %>% head(200), paste0("pitching_", tolower(.y$level))))
  to_json(pitching %>% head(500), "pitching_all")
}
if (!is.null(fg_bat))  to_json(fg_bat  %>% head(500), "fg_batting")
if (!is.null(fg_pit))  to_json(fg_pit  %>% head(500), "fg_pitching")

# ── Standings ─────────────────────────────────────────────────────────────────
standings <- read_proc("standings")
if (!is.null(standings)) {
  standings %>%
    group_by(level) %>%
    group_walk(~to_json(.x, paste0("standings_", tolower(.y$level))))
  to_json(standings, "standings_all")
}

# ── Recent transactions (last 30 days) ────────────────────────────────────────
trans <- read_proc("transactions")
if (!is.null(trans)) {
  recent <- trans %>% filter(date >= Sys.Date() - 30) %>% head(500)
  to_json(recent, "transactions_recent")
  to_json(trans %>% head(1000), "transactions_all")
}

# ── Schedule (recent + upcoming) ─────────────────────────────────────────────
sched <- read_proc("schedule")
if (!is.null(sched)) {
  to_json(sched %>% filter(game_date >= Sys.Date() - 3 & game_date <= Sys.Date() + 7) %>% head(300), "schedule_window")
  to_json(sched %>% filter(game_date <= Sys.Date()) %>% arrange(desc(game_date)) %>% head(300), "results_recent")
}

# ── Draft ────────────────────────────────────────────────────────────────────
draft <- read_proc("draft")
if (!is.null(draft)) to_json(draft %>% head(300), "draft")

# ── Metadata ─────────────────────────────────────────────────────────────────
last_updated <- read_proc("last_updated")
season <- if (!is.null(batting)) max(batting$season, na.rm = TRUE) else as.integer(format(Sys.Date(), "%Y"))

meta <- list(
  updated_utc    = if (!is.null(last_updated)) last_updated$updated_utc[1] else format(Sys.time(), tz="UTC", usetz=TRUE),
  season         = season,
  levels         = c("AAA","AA","HighA","A","Rookie"),
  sources        = c("MLB Stats API","FanGraphs","Baseball-Reference","Baseball Savant")
)
write(toJSON(meta, auto_unbox = TRUE), file.path(SITE_DIR, "meta.json"))
message("  [JSON] meta.json")

message(sprintf("\n✓ Site data built — %d JSON files in %s/", length(list.files(SITE_DIR)), SITE_DIR))
