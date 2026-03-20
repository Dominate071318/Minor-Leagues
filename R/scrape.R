# R/scrape.R
source("R/packages.R")
library(baseballr)
library(tidyverse)
library(httr)
library(jsonlite)

SEASON  <- if (nchar(Sys.getenv("SEASON")) > 0) as.integer(Sys.getenv("SEASON")) else as.integer(format(Sys.Date(), "%Y"))
RAW_DIR <- "data/raw"
dir.create(RAW_DIR, recursive = TRUE, showWarnings = FALSE)
message(paste("Season:", SEASON))

LEVELS <- list(
  list(id=11, name="AAA"),
  list(id=12, name="AA"),
  list(id=13, name="HighA"),
  list(id=14, name="A"),
  list(id=16, name="Rookie")
)

save_raw <- function(df, name) {
  if (!is.null(df) && nrow(df) > 0) {
    write.csv(df, file.path(RAW_DIR, paste0(name, ".csv")), row.names=FALSE)
    message(paste("[OK]", name, nrow(df), "rows"))
  } else {
    message(paste("[--]", name, "empty"))
  }
}

try_get <- function(expr, label) {
  tryCatch(expr, error=function(e) {
    message(paste("[ERR]", label, substr(e$message,1,80)))
    NULL
  })
}

# 1. Teams
message("=== Teams ===")
teams <- do.call(rbind, lapply(LEVELS, function(lvl) {
  Sys.sleep(0.3)
  try_get({
    url <- paste0("https://statsapi.mlb.com/api/v1/teams?sportId=",lvl$id,"&season=",SEASON)
    res <- jsonlite::fromJSON(url, flatten=TRUE)
    df  <- res$teams
    df$level  <- lvl$name
    df$season <- SEASON
    df[, intersect(names(df), c("id","name","abbreviation","teamCode","league.name","division.name","venue.name","level","season"))]
  }, paste("teams", lvl$name))
}))
save_raw(teams, "teams")

# 2. Standings
message("=== Standings ===")
standings <- do.call(rbind, lapply(LEVELS, function(lvl) {
  Sys.sleep(0.3)
  try_get({
    df <- mlb_standings(season=SEASON, sport_id=lvl$id)
    df$level  <- lvl$name
    df$season <- SEASON
    df
  }, paste("standings", lvl$name))
}))
save_raw(standings, "standings")

# 3. Player Stats
message("=== Player Stats ===")
player_stats <- do.call(rbind, lapply(LEVELS, function(lvl) {
  Sys.sleep(0.4)
  bat <- try_get({
    df <- mlb_stats(stat_type="season", stat_group="hitting", sport_id=lvl$id, season=SEASON)
    df$level <- lvl$name; df$group <- "batting"; df$season <- SEASON; df
  }, paste("bat", lvl$name))
  pit <- try_get({
    df <- mlb_stats(stat_type="season", stat_group="pitching", sport_id=lvl$id, season=SEASON)
    df$level <- lvl$name; df$group <- "pitching"; df$season <- SEASON; df
  }, paste("pit", lvl$name))
  rbind(bat, pit)
}))
save_raw(player_stats, "player_stats")

# 4. Rosters
message("=== Rosters ===")
if (!is.null(teams) && nrow(teams) > 0) {
  rosters <- do.call(rbind, lapply(teams$id, function(tid) {
    Sys.sleep(0.2)
    try_get({
      df <- mlb_rosters(team_id=tid, season=SEASON, roster_type="fullRoster")
      df$team_id <- tid; df$season <- SEASON; df
    }, paste("roster", tid))
  }))
  save_raw(rosters, "rosters")
}

# 5. Transactions
message("=== Transactions ===")
trans <- try_get(
  mlb_transactions(start_date=paste0(SEASON,"-01-01"), end_date=paste0(SEASON,"-12-31")),
  "transactions"
)
save_raw(trans, "transactions")

# 6. Schedule
message("=== Schedule ===")
schedule <- do.call(rbind, lapply(LEVELS, function(lvl) {
  Sys.sleep(0.3)
  try_get({
    url <- paste0("https://statsapi.mlb.com/api/v1/schedule?sportId=",lvl$id,"&season=",SEASON,"&gameType=R")
    res <- jsonlite::fromJSON(url, flatten=TRUE)
    if (is.null(res$dates) || length(res$dates)==0) return(NULL)
    df <- do.call(rbind, res$dates$games)
    df$level  <- lvl$name
    df$season <- SEASON
    df
  }, paste("schedule", lvl$name))
}))
save_raw(schedule, "schedule")

# 7. FanGraphs
message("=== FanGraphs ===")
fg_milb <- function(stat) {
  url <- paste0("https://www.fangraphs.com/api/leaders/minor-league/data?pos=all&stats=",stat,"&lg=2,4,5,6,7,8,9,10,11,14,16&qual=0&season=",SEASON,"&season1=",SEASON,"&pageitems=2000000&pagenum=1")
  res <- try_get(jsonlite::fromJSON(url, flatten=TRUE), paste("FG", stat))
  if (is.null(res) || is.null(res$data)) return(NULL)
  df <- as.data.frame(res$data)
  df$season <- SEASON
  df
}
save_raw(fg_milb("bat"), "fg_batting")
Sys.sleep(2)
save_raw(fg_milb("pit"), "fg_pitching")

# 8. Chadwick
message("=== Chadwick ===")
chadwick <- try_get(chadwick_player_lu(), "chadwick")
save_raw(chadwick, "chadwick")

message(paste("Done! Files:", length(list.files(RAW_DIR))))

