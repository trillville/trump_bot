
# Load all tweets and update local data file ------------------------------------------------------------------------

loadAllTweets <- function(start.date) {
  setup_twitter_oauth(Sys.getenv("TWITTER_CONSUMER_KEY"),
                      Sys.getenv("TWITTER_CONSUMER_SECRET"),
                      Sys.getenv("TWITTER_ACCESS_TOKEN"),
                      Sys.getenv("TWITTER_ACCESS_SECRET"))
  
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


# Add features to a data frame of tweets ------------------------------------------------------------------------

addFeatures <- function(df) {
  tweets <- df %>%
    extract(statusSource, into = "source", regex = "Twitter for (.*?)<") %>%
    mutate(hour = hour(with_tz(created, "EST")), tweet.date = date(created)) %>%
    select(-favorited, -favoriteCount, -replyToSN, -truncated, -replyToSID, -replyToUID,
           -screenName, -retweetCount, -retweeted, -longitude, -latitude)
  
  # has.quotes indicates a tweet wrapped in quotation marks 
  tweets$has.quotes <- ifelse(str_detect(tweets$text, c('^"')), 1, 0)
  
  # was a picture or link included?
  tweets$has.pic.link <- ifelse(str_detect(tweets$text, "t.co"), 1, 0)
  
  # Sentiment Analysis ------------------------------------------------------
  
  reg <- "([^A-Za-z\\d#@']|'(?![A-Za-z\\d#@]))"
  
  all.words <- tweets %>%
    filter(!str_detect(text, '^"')) %>%
    mutate(text = str_replace_all(text, "https://t.co/[A-Za-z\\d]+|&amp;", "")) %>%
    unnest_tokens(word, text, token = "regex", pattern = reg) %>%
    filter(!word %in% stop_words$word, str_detect(word, "[a-z]")) %>% # drop stop words
    select(id, word, source)
  
  nrc <- sentiments %>%
    filter(lexicon == "nrc") %>%
    dplyr::select(word, sentiment)
  
  all.words <- left_join(all.words, nrc,
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
           anticipation = sum(sentiment == "anticipation", na.rm = TRUE),
           num.words    = n()) %>%
    filter(row_number(word) == 1) %>%
    select(-word, -sentiment)
  
  tweets <- left_join(tweets, all.words)
  tweets[, EMOTIONS] <- apply(tweets[, EMOTIONS], 2, function(x) {replace(x, is.na(x), 0)})
  
  tweets$total.emotion <- rowSums(tweets[, EMOTIONS])
  
  return (tweets)
}


# Make Predictions for all tweets since last.id ---------------------------

predictTweets <- function(last.id) {
  tweets <- tbl_df(map_df(userTimeline("realDonaldTrump", n = 50, sinceID = last.id), as.data.frame))
  tweets <- addFeatures(tweets)
  load("model.RData") # load model1
  preds <- predict(model1, tweets, type = "response")
  out <- data.frame(tweets$id, preds)
  colnames(out) <- c("id", "prediction")
  return(out)
}
