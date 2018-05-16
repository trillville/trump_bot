remove.packages("rtweet")
if (!"dplyr" %in% installed.packages()) {
	install.packages("dplyr", dependencies = TRUE)
}

if (!"purrr" %in% installed.packages()) {
	install.packages("purrr", dependencies = TRUE)
}

if (!"lubridate" %in% installed.packages()) {
	install.packages("lubridate", dependencies = TRUE)
}

if (!"scales" %in% installed.packages()) {
	install.packages("scales", dependencies = TRUE)
}

if (!"stringr" %in% installed.packages()) {
	install.packages("stringr", dependencies = TRUE)
}

if (!"tidytext" %in% installed.packages()) {
	install.packages("tidytext", dependencies = TRUE)
}

if (!"gam" %in% installed.packages()) {
	install.packages("gam", dependencies = TRUE)
}

if (!"readr" %in% installed.packages()) {
	install.packages("readr", dependencies = TRUE)
}

if (!"httpuv" %in% installed.packages()) {
  install.packages("httpuv", dependencies = TRUE)
}

if (!"devtools" %in% installed.packages()) {
  install.packages("devtools", dependencies = TRUE)
}

if (!"rtweet" %in% installed.packages()) {
  devtools::install_github("mkearney/rtweet")
}
