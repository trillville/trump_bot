library(dplyr)
library(purrr)
library(twitteR)
library(ggplot2)
library(tidyr)
library(lubridate)
library(scales)
library(stringr)
library(tidytext)
library(matrixStats)

# twitter API keys used
source("keys.R")

# Constants ---------------------------------------------------------------

START_DATE <- as.Date("2016-01-09")

EMOTIONS <- c("trust", "fear", "negative", "sadness", "anger", "surprise", "positive", "disgust", "joy", "anticipation")

# Functions ---------------------------------------------------------------

loadTweets <- function(start.date) {
  setup_twitter_oauth(twitter_consumer,
                      twitter_consumer_secret,
                      twitter_access_token,
                      twitter_access_secret)
  
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

# has.quotes indicates a tweet wrapped in quotation marks 
tweets$has.quotes <- ifelse(str_detect(tweets$text, c('^"')), 1, 0)

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

tweets$total.emotion <- rowSums(tweets[, EMOTIONS])

# Modeling -------------------------------------------------------------------

tweets <- tweets[complete.cases(tweets), ]
tweets$trump <- as.factor(ifelse(tweets$source == "Android", 1, 0))
x.vars <- as.matrix(select(tweets, hour, has.quotes, has.pic.link, trust, fear, negative, sadness, 
                          anger, surprise, positive, disgust, joy, anticipation))
train <- sample(nrow(tweets), nrow(tweets)/2)

# TODO - replace with actual manual training results
y.var <- tweets$trump

# LOGISTIC REGRESSION
model1 <- glm(trump ~ hour + has.quotes + has.pic.link + trust + fear + negative + 
                sadness + anger + surprise + positive + disgust + joy + anticipation, 
              family = binomial(),
              data = tweets)

# Unused Models -----------------------------------------------------------

# # XGBOOST
# library(xgboost)
# xgb.x <- as.matrix(select(tweets, hour, has.quotes, has.pic.link, trust, fear, negative, sadness, 
#                 anger, surprise, positive, disgust, joy, anticipation))
# xgb.y <- tweets$trump
# 
# model3 <- xgboost(data = xgb.x[train, ], label = xgb.y[train], objective = "binary:logistic", eta = 0.01, nrounds = 1000)
# probs2 <- predict(model3, xgb.x[-train, ])


# RIDGE
# cv2 <- cv.glmnet(x = xgb.x[train, ], y = xgb.y[train], type.measure = "class", family = "binomial", alpha = 0)
# model5 <- glmnet(x = xgb.x[train, ], y = xgb.y[train], family = "binomial", alpha = 0, lambda = 0.06273243)
# probs <- predict(model5, xgb.x[-train, ], type = "response")
# preds <- ifelse(probs > 0.5, 1, 0)

# RANDOMFOREST
# library(randomForest)
# model2 <- randomForest(x = x.vars[train, ], y = y.var[train], xtest = x.vars[-train, ], ytest = y.var[-train])
# 
# preds <- model2$votes[, 2]
# table(preds, tweets$trump[-train])
# 
# 
# # LASSO
# library(glmnet)
# #cv1 <- cv.glmnet(x = xgb.x[train, ], y = xgb.y[train], type.measure = "class", family = "binomial", alpha = 1)
# model3 <- glmnet(x = x.vars[train, ], y = y.var[train], family = "binomial", alpha = 1, lambda = 0.02911781)
# 
# probs1 <- predict(model1, tweets[-train, ], type = "response")
# probs2 <- model2$votes[, 2]
# probs3 <- predict(model3, x.vars[-train, ], type = "response")
# 
# all.probs <- cbind(probs1, probs2, probs3)
# 
# # geometric mean
# probs <- rowProds(all.probs)^(1/ncol(all.probs))
# probs <- rowMeans(all.probs)
# preds <- ifelse(probs > 0.5, 1, 0)
# table(preds, y.var[-train])

