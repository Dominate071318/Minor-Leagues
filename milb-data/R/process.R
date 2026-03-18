# R/process.R — clean & merge raw CSVs into analysis-ready tables
library(tidyverse); library(lubridate)

RAW  <- "data/raw"
PROC <- "data/processed"
dir.create(PROC, recursive = TRUE, showWarnings = FALSE)

read_raw <- function(name) {
  path <- file.path(RAW, paste0(name, ".csv"))
  if (!file.exists(path)) { message(sprintf("  [skip] %s not found", name)); return(NULL) }
  read_csv(path, show_col_types = FALSE)
}

save_proc <- function(df, name) {
  if (is.null(df) || nrow(df) == 0) return(invisible(NULL))
  write_csv(df, file.path(PROC, paste0(name, ".csv")))
  message(sprintf("  [OK] %-35s %d rows", name, nrow(df)))
}

# ── Standings ─────────────────────────────────────────────────────────────────
standings <- read_raw("standings")
if (!is.null(standings)) {
  standings_clean <- standings %>%
    select(any_of(c("level","season","team_name","team_id","wins","losses",
                    "pct","games_back","streak","runs","runs_allowed","division_rank"))) %>%
    mutate(across(c(wins, losses, runs, runs_allowed), as.integer),
           pct = round(as.numeric(pct), 3))
  save_proc(standings_clean, "standings")
}

# ── Player Stats ──────────────────────────────────────────────────────────────
stats <- read_raw("player_stats")
if (!is.null(stats)) {
  batting <- stats %>%
    filter(group == "batting") %>%
    select(any_of(c("level","season","player_full_name","player_id","team_name",
                    "position_abbreviation","games_played","at_bats","hits","doubles",
                    "triples","home_runs","rbi","stolen_bases","avg","obp","slg","ops",
                    "strike_outs","base_on_balls","plate_appearances"))) %>%
    mutate(across(c(games_played, at_bats, hits, home_runs, rbi, stolen_bases,
                    strike_outs, base_on_balls, plate_appearances), as.integer),
           across(c(avg, obp, slg, ops), ~round(as.numeric(.x), 3))) %>%
    arrange(level, desc(ops))

  pitching <- stats %>%
    filter(group == "pitching") %>%
    select(any_of(c("level","season","player_full_name","player_id","team_name",
                    "position_abbreviation","games_played","games_started","wins","losses",
                    "era","innings_pitched","strike_outs","base_on_balls","hits",
                    "home_runs","whip","batting_avg_against"))) %>%
    mutate(across(c(games_played, games_started, wins, losses, strike_outs,
                    base_on_balls, hits, home_runs), as.integer),
           across(c(era, whip, batting_avg_against), ~round(as.numeric(.x), 3))) %>%
    arrange(level, era)

  save_proc(batting,  "batting")
  save_proc(pitching, "pitching")
}

# ── Rosters ───────────────────────────────────────────────────────────────────
rosters <- read_raw("rosters")
if (!is.null(rosters)) {
  rosters_clean <- rosters %>%
    select(any_of(c("team_id","season","person.fullName","person.id","jerseyNumber",
                    "position.name","position.abbreviation","position.type",
                    "status.description"))) %>%
    rename_with(~str_remove(.x, "person\\.|position\\.|status\\.")) %>%
    distinct()
  save_proc(rosters_clean, "rosters")
}

# ── Transactions ──────────────────────────────────────────────────────────────
trans <- read_raw("transactions")
if (!is.null(trans)) {
  trans_clean <- trans %>%
    select(any_of(c("date","effectiveDate","typeDesc","player.fullName","player.id",
                    "fromTeam.name","toTeam.name","description"))) %>%
    rename_with(~str_remove(.x, "player\\.|fromTeam\\.|toTeam\\.")) %>%
    mutate(date = as_date(date)) %>%
    arrange(desc(date))
  save_proc(trans_clean, "transactions")
}

# ── Schedule / Results ────────────────────────────────────────────────────────
sched <- read_raw("schedule")
if (!is.null(sched)) {
  sched_clean <- sched %>%
    select(any_of(c("level","season","gamePk","gameDate",
                    "teams.away.team.name","teams.away.score",
                    "teams.home.team.name","teams.home.score",
                    "status.detailedState","venue.name"))) %>%
    rename(game_id = gamePk, game_date = gameDate,
           away_team = `teams.away.team.name`, away_score = `teams.away.score`,
           home_team = `teams.home.team.name`, home_score = `teams.home.score`,
           status = `status.detailedState`, venue = `venue.name`) %>%
    mutate(game_date = as_date(game_date)) %>%
    arrange(desc(game_date))
  save_proc(sched_clean, "schedule")
}

# ── FanGraphs ─────────────────────────────────────────────────────────────────
fg_bat <- read_raw("fg_batting")
fg_pit <- read_raw("fg_pitching")

if (!is.null(fg_bat)) {
  fg_bat_clean <- fg_bat %>%
    select(any_of(c("season","Name","Team","Age","Level","G","PA","HR","R","RBI",
                    "SB","BB%","K%","AVG","OBP","SLG","OPS","wOBA","wRC+","WAR",
                    "playerid"))) %>%
    arrange(desc(`wRC+`))
  save_proc(fg_bat_clean, "fg_batting")
}

if (!is.null(fg_pit)) {
  fg_pit_clean <- fg_pit %>%
    select(any_of(c("season","Name","Team","Age","Level","G","GS","IP","W","L",
                    "SV","K/9","BB/9","HR/9","ERA","FIP","xFIP","WHIP","K%","BB%",
                    "WAR","playerid"))) %>%
    arrange(ERA)
  save_proc(fg_pit_clean, "fg_pitching")
}

# ── Draft ─────────────────────────────────────────────────────────────────────
draft <- read_raw("draft")
if (!is.null(draft)) {
  draft_clean <- draft %>%
    select(any_of(c("season","drafts.rounds.picks.pickNumber","drafts.rounds.picks.roundPickNumber",
                    "drafts.rounds.roundNumber","drafts.rounds.picks.person.fullName",
                    "drafts.rounds.picks.team.name","drafts.rounds.picks.school.name",
                    "drafts.rounds.picks.position.abbreviation","drafts.rounds.picks.signingBonus"))) %>%
    rename_with(~str_remove_all(.x, "drafts\\.rounds\\.picks\\.|drafts\\.rounds\\."))
  save_proc(draft_clean, "draft")
}

# ── Metadata: last_updated ────────────────────────────────────────────────────
tibble(updated_utc = format(Sys.time(), tz = "UTC", usetz = TRUE)) %>%
  write_csv(file.path(PROC, "last_updated.csv"))

message(sprintf("\n✓ Processing complete — %s", Sys.time()))
message(sprintf("  Files in %s/: %d", PROC, length(list.files(PROC))))
