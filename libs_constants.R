library(rtweet)
library(lubridate)
library(scales)
library(tidytext)
library(gam)
library(httpuv)
library(RPostgres)
library(httr)
library(dbplyr)
library(tidyverse)

# Constants ---------------------------------------------------------------

START_DATE <- as.Date("2016-01-09")

EMOTIONS <- c("trust", "fear", "negative", "sadness", "anger", "surprise", "positive", "disgust", "joy", "anticipation")

MODEL_FEATURES <- c("hour", EMOTIONS, "num.words", "user.score", "has.pic.link")

PREFIX_WORDS <- c("Low Energy", "Phony", "Dopey", "Neurotic", "Lightweight",  "Goofy", "Crooked", "Lyin'", "Unattractive",
                  "High Energy", "Big League", "Rocket Man", "Cryin'")

SUFFIX_WORDS <- c("Weak!", "Dummy!", "Loser!", "Bad!", "ISIS!", "Disloyal!", "Sad!", "China!", 
                  "ENJOY!", "NO COLLUSION!")