# R/packages.R — install all dependencies
pkgs <- c("baseballr", "tidyverse", "rvest", "httr", "jsonlite", "lubridate", "glue")
missing <- pkgs[!pkgs %in% installed.packages()[, "Package"]]
if (length(missing)) install.packages(missing, repos = "https://cloud.r-project.org")
