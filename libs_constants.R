library(dplyr)
library(purrr)
library(twitteR)
library(tidyr)
library(lubridate)
library(scales)
library(stringr)
library(tidytext)
library(readr)
library(gam)


# Constants ---------------------------------------------------------------

START_DATE <- as.Date("2016-01-09")

EMOTIONS <- c("trust", "fear", "negative", "sadness", "anger", "surprise", "positive", "disgust", "joy", "anticipation")
