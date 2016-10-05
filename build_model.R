library(dplyr)
library(purrr)
library(twitteR)
library(ggplot2)
library(tidyr)
library(lubridate)
library(scales)
library(stringr)
library(tidytext)


# Constants ---------------------------------------------------------------

START_DATE <- as.Date("2016-01-09")

key1 <- "oM1hgqPFxQaK15pIcSmMdvX53"
key2 <- "jXqFrTeOyXYRHHI75wsynSFs4yC3NNIpZCtdo4CH07RYp2ufA7"
key3 <- "236160526-P0mC2y1EgprUFwPPKBWNmaLoNOA1RVyTUVu65ebo"
key4 <- "5vWAvb3fsCSzGVsENYIDZ3dhfCYTv4FZwDcMMqdkfx3R8"

EMOTIONS <- c("trust", "fear", "negative", "sadness", "anger", "surprise", "positive", "disgust", "joy", "anticipation")

# Functions ---------------------------------------------------------------

loadTweets <- function(start.date) {
  setup_twitter_oauth(key1,
                      key2,
                      key3,
                      key4)
  
  out <- tryCatch({
    load("trump_tweets.Rdata")
    current.max.id <- trump.tweets$id[which.max(trump.tweets$created)]
    message("loading new tweets...")
    trump.tweets <- rbind(trump.tweets, tbl_df(map_df(userTimeline("realDonaldTrump", n = 3200, sinceID = current.max.id), as.data.frame)))
    save(trump.tweets, file = "trump_tweets.RData")
    return(trump.tweets)
  },
    
  warning = function(cond) {
    message("Data not found, downloading...")
    message("loading...")
    trump.tweets <- tbl_df(map_df(userTimeline("realDonaldTrump", n = 100), as.data.frame))
    current.min <- min(trump.tweets$created)
    while (as.Date(current.min) >= START_DATE) {
      message(paste("loading... oldest tweet so far:", min(as.Date(trump.tweets$created))))
      current.min <- min(trump.tweets$created)
      current.min.id <- trump.tweets$id[which(trump.tweets$created == current.min)]
      trump.tweets <- trump.tweets[-which(trump.tweets$id == current.min.id), ]
      trump.tweets <- rbind(trump.tweets, tbl_df(map_df(userTimeline("realDonaldTrump", n = 100, maxID = current.min.id), as.data.frame)))
    }
    save(trump.tweets, file = "trump_tweets.RData")
    return(trump.tweets)
    }
  )
  return(out)
}


# Set up Data ---------------------------------------------------------------

trump.tweets <- loadTweets(START_DATE)

tweets <- trump.tweets %>%
  extract(statusSource, into = "source", regex = "Twitter for (.*?)<") %>%
  mutate(hour = hour(with_tz(created, "EST")), tweet.date = date(created)) %>%
  select(id, text, source, favoriteCount, retweetCount, isRetweet, created, tweet.date, hour)

# has.quotes indicates a tweet wrapped in quotation marks (seems to be a thing he does)
tweets$has.quotes <- ifelse(str_detect(tweets$text, '^"'), 1, 0)

# was a picture or link included?
tweets$has.pic.link <- ifelse(str_detect(tweets$text, "t.co"), 1, 0)

# Sentiment Analysis ------------------------------------------------------

reg <- "([^A-Za-z\\d#@']|'(?![A-Za-z\\d#@]))"

sentiment.table <- tweets %>%
  filter(!str_detect(text, '^"')) %>%
  mutate(text = str_replace_all(text, "https://t.co/[A-Za-z\\d]+|&amp;", "")) %>%
  unnest_tokens(word, text, token = "regex", pattern = reg) %>%
  filter(!word %in% stop_words$word, str_detect(word, "[a-z]")) %>% # filler words like
  select(id, word)

nrc <- sentiments %>%
  filter(lexicon == "nrc") %>%
  dplyr::select(word, sentiment)

sentiment.table <- left_join(sentiment.table, nrc,
                         by = c("word" = "word")) %>%
  group_by(id) %>%
  mutate(trust        = sum(sentiment == "trust", na.rm = TRUE),
         fear         = sum(sentiment == "fear", na.rm = TRUE),
         negative     = sum(sentiment == "negative", na.rm = TRUE),
         sadness      = sum(sentiment == "sadness", na.rm = TRUE),
         anger        = sum(sentiment == "anger", na.rm = TRUE),
         surprise     = sum(sentiment == "surprise", na.rm = TRUE),
         positive     = sum(sentiment == "positive", na.rm = TRUE),
         disgust      = sum(sentiment == "disgust", na.rm = TRUE),
         joy          = sum(sentiment == "joy", na.rm = TRUE),
         anticipation = sum(sentiment == "anticipation", na.rm = TRUE)) %>%
  filter(row_number(word) == 1) %>%
  select(-word, -sentiment)

tweets <- left_join(tweets, sentiment.table)
tweets[, EMOTIONS] <- apply(tweets[, EMOTIONS], 2, function(x) {replace(x, is.na(x), 0)})
