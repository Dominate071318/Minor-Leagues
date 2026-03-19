# R/scrape.R — MiLB data scraper (called by GitHub Actions)
source("R/packages.R")
library(baseballr); library(tidyverse); library(rvest); library(httr); library(jsonlite)

# ── Config ────────────────────────────────────────────────────────────────────
SEASON      <- if (nchar(Sys.getenv("SEASON")) > 0) as.integer(Sys.getenv("SEASON")) else as.integer(format(Sys.Date(), "%Y"))
RAW_DIR     <- "data/raw"
# live = games happening now (fast, API only)
# full = no live games (everything including B-Ref, FanGraphs, Savant)
SCRAPE_MODE <- if (nchar(Sys.getenv("SCRAPE_MODE")) > 0) Sys.getenv("SCRAPE_MODE") else "full"
dir.create(RAW_DIR, recursive = TRUE, showWarnings = FALSE)
message(sprintf("Mode: %s | Season: %d | %s", SCRAPE_MODE, SEASON, Sys.time()))

LEVELS     <- list(
  list(id = 11, name = "AAA"),
  list(id = 12, name = "AA"),
  list(id = 13, name = "HighA"),
  list(id = 14, name = "A"),
  list(id = 16, name = "Rookie")
)

MLBcodes   <- c("ARI","ATL","BAL","BOS","CHC","CHW","CIN","CLE","COL","DET",
                "HOU","KCA","LAA","LAD","MIA","MIL","MIN","NYM","NYY","OAK",
                "PHI","PIT","SDP","SFG","SEA","STL","TBR","TEX","TOR","WSN")

# ── Helpers ───────────────────────────────────────────────────────────────────
save_raw <- function(df, name) {
  if (!is.null(df) && nrow(df) > 0) {
    write_csv(df, file.path(RAW_DIR, paste0(name, ".csv")))
    message(sprintf("  [OK] %-40s %d rows", name, nrow(df)))
  } else {
    message(sprintf("  [--] %-40s empty", name))
  }
}

try_get <- function(expr, label) {
  tryCatch(expr, error = function(e) {
    message(sprintf("  [ERR] %s: %s", label, substr(e$message, 1, 80)))
    NULL
  })
}

# ── 1. MLB Stats API — Teams ──────────────────────────────────────────────────
message("\n=== 1. MLB STATS API: Teams ===")
teams <- map_dfr(LEVELS, function(lvl) {
  try_get({
    res <- fromJSON(sprintf("https://statsapi.mlb.com/api/v1/teams?sportId=%d&season=%d", lvl$id, SEASON), flatten = TRUE)
    res$teams %>% select(any_of(c("id","name","abbreviation","teamCode","league.name","division.name","venue.name","venue.city"))) %>%
      mutate(level = lvl$name, season = SEASON)
  }, paste("teams", lvl$name))
})
save_raw(teams, "teams")

# ── 2. Standings ──────────────────────────────────────────────────────────────
message("\n=== 2. Standings ===")
standings <- map_dfr(LEVELS, function(lvl) {
  Sys.sleep(0.3)
  try_get({
    mlb_standings(season = SEASON, sport_id = lvl$id) %>% mutate(level = lvl$name, season = SEASON)
  }, paste("standings", lvl$name))
})
save_raw(standings, "standings")

# ── 3. Player Stats ───────────────────────────────────────────────────────────
message("\n=== 3. Player Stats ===")
player_stats <- map_dfr(LEVELS, function(lvl) {
  Sys.sleep(0.4)
  bat <- try_get(mlb_stats(stat_type = "season", stat_group = "hitting",  sport_id = lvl$id, season = SEASON) %>% mutate(level = lvl$name, group = "batting",  season = SEASON), paste("bat", lvl$name))
  pit <- try_get(mlb_stats(stat_type = "season", stat_group = "pitching", sport_id = lvl$id, season = SEASON) %>% mutate(level = lvl$name, group = "pitching", season = SEASON), paste("pit", lvl$name))
  bind_rows(bat, pit)
})
save_raw(player_stats, "player_stats")

# ── 4. Rosters ────────────────────────────────────────────────────────────────
message("\n=== 4. Rosters ===")
if (!is.null(teams) && nrow(teams) > 0) {
  rosters <- map_dfr(teams$id, function(tid) {
    Sys.sleep(0.25)
    try_get(mlb_rosters(team_id = tid, season = SEASON, roster_type = "fullRoster") %>% mutate(team_id = tid, season = SEASON), paste("roster", tid))
  })
  save_raw(rosters, "rosters")
}

# ── 5. Transactions ───────────────────────────────────────────────────────────
message("\n=== 5. Transactions ===")
trans <- try_get(
  mlb_transactions(start_date = paste0(SEASON, "-01-01"), end_date = paste0(SEASON, "-12-31")),
  "transactions"
)
save_raw(trans, "transactions")

# ── 6. Draft ──────────────────────────────────────────────────────────────────
message("\n=== 6. Draft ===")
draft <- try_get(mlb_draft(year = SEASON), "draft")
save_raw(draft, "draft")

# ── 7. Schedule / Results ─────────────────────────────────────────────────────
message("\n=== 7. Schedule ===")
schedule <- map_dfr(LEVELS, function(lvl) {
  Sys.sleep(0.3)
  try_get({
    res <- fromJSON(sprintf("https://statsapi.mlb.com/api/v1/schedule?sportId=%d&season=%d&gameType=R", lvl$id, SEASON), flatten = TRUE)
    if (length(res$dates) == 0) return(NULL)
    bind_rows(res$dates$games) %>% mutate(level = lvl$name, season = SEASON)
  }, paste("schedule", lvl$name))
})
save_raw(schedule, "schedule")

# ── 8. FanGraphs MiLB Leaderboards ───────────────────────────────────────────
message("\n=== 8. FanGraphs ===")
fg_milb <- function(stat) {
  url <- sprintf("https://www.fangraphs.com/api/leaders/minor-league/data?pos=all&stats=%s&lg=2,4,5,6,7,8,9,10,11,14,16&qual=0&season=%d&season1=%d&pageitems=2000000&pagenum=1", stat, SEASON, SEASON)
  res <- try_get(fromJSON(url, flatten = TRUE), paste("FG", stat))
  if (is.null(res) || is.null(res$data)) return(NULL)
  as_tibble(res$data) %>% mutate(season = SEASON)
}
save_raw(fg_milb("bat"), "fg_batting")
Sys.sleep(2)
save_raw(fg_milb("pit"), "fg_pitching")

# ── 9. Baseball-Reference Org Batting (FULL mode only — too slow for live updates)
if (SCRAPE_MODE == "full") { # ── start full-only block ────────────────────────────────────────
message("\n=== 9. Baseball-Reference ===")
bref_list <- map(MLBcodes, function(tm) {
  message(sprintf("  B-Ref %s...", tm))
  Sys.sleep(3)
  try_get({
    url  <- sprintf("https://www.baseball-reference.com/minors/affiliate.cgi?id=%s&year=%d", tm, SEASON)
    page <- read_html(url)
    node <- html_node(page, "#team_batting")
    if (is.null(node)) return(NULL)
    html_table(node, header = TRUE) %>% as_tibble(.name_repair = "unique") %>%
      mutate(team_code = tm, season = SEASON)
  }, paste("bref", tm))
})
save_raw(bind_rows(compact(bref_list)), "bref_org_batting")

# ── 10. Savant MiLB Statcast (AAA) ───────────────────────────────────────────
message("\n=== 10. Baseball Savant ===")
savant <- try_get({
  url <- paste0(
    "https://baseballsavant.mlb.com/statcast_search/csv?all=true",
    "&hfGT=R%7C&hfSea=", SEASON, "%7C",
    "&game_date_gt=", SEASON, "-04-01",
    "&game_date_lt=", SEASON, "-09-30",
    "&hfFlag=is%5C.%5C.milb%7C",
    "&player_type=pitcher&min_pitches=0&min_results=0",
    "&group_by=name&sort_col=pitches&sort_order=desc&type=details"
  )
  resp <- GET(url, timeout(180))
  if (status_code(resp) != 200) return(NULL)
  read_csv(content(resp, "text"), show_col_types = FALSE) %>% mutate(season = SEASON)
}, "Savant AAA")
save_raw(savant, "savant_aaa")
# ── 11. Chadwick Player ID Register ─────────────────────────────────────────
message("\n=== 11. Chadwick ===")
chadwick <- try_get(chadwick_player_lu(), "chadwick")
save_raw(chadwick, "chadwick")

# ── Done ──────────────────────────────────────────────────────────────────────
message(sprintf("\n✓ Scrape complete — season %d — %s", SEASON, Sys.time()))
message(sprintf("  Files in %s/: %d", RAW_DIR, length(list.files(RAW_DIR))))
