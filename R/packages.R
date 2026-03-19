options(repos = c(CRAN = 'https://cloud.r-project.org'))
pkgs <- c('qs','baseballr','tidyverse','rvest','httr','jsonlite','lubridate','glue')
missing <- pkgs[!pkgs %in% installed.packages()[,'Package']]
if (length(missing) > 0) install.packages(missing, dependencies = TRUE)
message('All packages ready')
