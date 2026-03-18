# ⚾ MiLB Data Hub

A fully automated pipeline that scrapes minor league baseball data daily and serves it as a static website via GitHub Pages.

---

## Architecture

```
┌─────────────────────────────────────────────────────┐
│  GitHub Actions (daily cron @ 9am UTC)              │
│                                                     │
│  R/scrape.R ──► data/raw/*.csv                     │
│       │                                             │
│  R/process.R ──► data/processed/*.csv              │
│       │                                             │
│  R/build_site_data.R ──► docs/data/*.json          │
│                                │                    │
│                         git push ──► GitHub Pages   │
└─────────────────────────────────────────────────────┘
         https://your-username.github.io/milb-data
```

## Data Sources

| Source | What's pulled |
|---|---|
| **MLB Stats API** | Teams, rosters, standings, player stats (bat+pitch), transactions, draft, schedule — all 5 levels |
| **FanGraphs** | MiLB batting & pitching leaderboards (wRC+, FIP, WAR) |
| **Baseball-Reference** | Org batting tables for all 30 MLB affiliates |
| **Baseball Savant** | Statcast pitch-level data (Triple-A + Florida State League) |
| **Chadwick Register** | Cross-reference IDs (MLBAM, bref, FanGraphs, Retrosheet) |

## Levels Covered

`AAA` · `AA` · `High-A` · `Single-A` · `Rookie`

---

## Quick Start

### 1. Fork & clone this repo

```bash
git clone https://github.com/YOUR_USERNAME/milb-data.git
cd milb-data
```

### 2. Enable GitHub Pages

- Go to **Settings → Pages**
- Source: **Deploy from a branch** → `main` → `/docs`
- OR use **GitHub Actions** (workflow already configured)

### 3. Enable GitHub Actions write permissions

- **Settings → Actions → General → Workflow permissions**
- Select **Read and write permissions**

### 4. Trigger your first run

```
Actions → MiLB Data Refresh → Run workflow
```

The workflow will scrape all sources, process the data, write JSON to `docs/data/`, commit, and deploy the site automatically.

### 5. Run locally

```r
# Install dependencies
source("R/packages.R")

# Set season (optional — defaults to current year)
Sys.setenv(SEASON = "2024")

# Run pipeline
source("R/scrape.R")
source("R/process.R")
source("R/build_site_data.R")

# Preview site — open docs/index.html in your browser
# Or serve locally:
# python3 -m http.server 8080 --directory docs
```

---

## File Structure

```
milb-data/
├── .github/
│   └── workflows/
│       └── scrape.yml          # Daily cron + manual trigger
├── R/
│   ├── packages.R              # Install all deps
│   ├── scrape.R                # Pull from all sources → data/raw/
│   ├── process.R               # Clean & merge → data/processed/
│   └── build_site_data.R       # Export JSON → docs/data/
├── data/
│   ├── raw/                    # Raw CSVs (committed to git)
│   └── processed/              # Analysis-ready CSVs
├── docs/
│   ├── index.html              # Static website
│   └── data/                   # JSON files consumed by the site
└── README.md
```

## Raw Data Files

| File | Description |
|---|---|
| `data/raw/teams.csv` | All MiLB teams by level |
| `data/raw/standings.csv` | Season standings |
| `data/raw/player_stats.csv` | Batting + pitching stats (MLB API) |
| `data/raw/rosters.csv` | Full rosters by team |
| `data/raw/transactions.csv` | Full season transactions |
| `data/raw/draft.csv` | Draft picks |
| `data/raw/schedule.csv` | Full schedule + results |
| `data/raw/fg_batting.csv` | FanGraphs batting leaderboard |
| `data/raw/fg_pitching.csv` | FanGraphs pitching leaderboard |
| `data/raw/bref_org_batting.csv` | B-Ref org batting (30 teams) |
| `data/raw/savant_aaa.csv` | Statcast pitch data (AAA) |
| `data/raw/chadwick.csv` | Player ID cross-reference |

## Customizing

**Change season:** Edit `SEASON` in `R/scrape.R` or pass via env var:
```bash
SEASON=2025 Rscript R/scrape.R
```

**Add a specific player's B-Ref page:**
```r
source("R/scrape.R")
bref_player_milb("troutmi01")   # returns all MiLB seasons
```

**Get pitch-by-pitch for a specific date:**
```r
library(baseballr)
pks <- get_game_pks_mlb(date = "2024-08-15", level_ids = c(11,12))
pbp <- mlb_pbp(game_pk = pks$game_pk[1])
```

---

## Notes

- Baseball-Reference scraping uses `Sys.sleep(3)` between requests — please don't remove this
- Savant MiLB Statcast is mainly available for AAA and the Florida State League (ABS-equipped parks)
- FanGraphs endpoints are unofficial and may change; check `R/scrape.R` if they break
- Large CSVs (savant, PBP) are gitignored by default — add them to `.gitignore` if repo size becomes an issue

## License

Data is sourced from publicly accessible APIs and websites. Usage subject to each source's terms of service. Code is MIT licensed.
