
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
  
  tweets$source <- ifelse(is.na(tweets$source), "Other", ifelse(tweets$source != "Android",
                                                                  "Other", "Android"))
  
  # has.quotes indicates a tweet wrapped in quotation marks 
  tweets$has.quotes <- ifelse(str_detect(tweets$text, c('^"')), 1, 0)
  
  # was a picture or link included?
  tweets$has.pic.link <- ifelse(str_detect(tweets$text, "t.co"), 1, 0)
  
  # Sentiment Analysis ------------------------------------------------------
  
  all.words <- breakOutWords(tweets)
  
  nrc <- sentiments %>%
    filter(lexicon == "nrc") %>%
    dplyr::select(word, sentiment)
  
  sentiment.table<- left_join(all.words, nrc,
                         by = c("word" = "word")) %>%
    group_by(id) %>%
    summarise(trust        = sum(sentiment == "trust", na.rm = TRUE),
           fear         = sum(sentiment == "fear", na.rm = TRUE),
           negative     = sum(sentiment == "negative", na.rm = TRUE),
           sadness      = sum(sentiment == "sadness", na.rm = TRUE),
           anger        = sum(sentiment == "anger", na.rm = TRUE),
           surprise     = sum(sentiment == "surprise", na.rm = TRUE),
           positive     = sum(sentiment == "positive", na.rm = TRUE),
           disgust      = sum(sentiment == "disgust", na.rm = TRUE),
           joy          = sum(sentiment == "joy", na.rm = TRUE),
           anticipation = sum(sentiment == "anticipation", na.rm = TRUE),
           num.words    = n())
  
  load("trump_dict.RData")
  odds.table <- left_join(all.words, trump.dict) %>%
    group_by(id) %>%
    summarise(user.score = sum(logratio, na.rm = TRUE))
    
  tweets <- left_join(tweets, sentiment.table) %>%
    left_join(odds.table)
  
  tweets[, c(EMOTIONS, "user.score")] <- apply(tweets[, c(EMOTIONS, "user.score")], 2, function(x) {replace(x, is.na(x), 0)})
  
  tweets$total.emotion <- rowSums(tweets[, EMOTIONS])
  
  return (tweets)
}

# takes a DF of words mapped to ID, and returns a DF 
# showing log ratio (higher = more likely to be trump)
updateTrumpDict <- function(df, cutoff) {
  all.words <- breakOutWords(df, include.source = TRUE) 
  
  trump.dict <- count(all.words,word, trump) %>%
    filter(sum(n) >= cutoff) %>%
    spread(trump, n, fill = 0) %>%
    ungroup() %>%
    mutate_each(funs((. + 1) / sum(. + 1)), -word) %>%
    mutate(logratio = log2(`1` / `0`)) %>%
    arrange(desc(logratio)) %>%
    select(-`0`, -`1`)
  
  save(trump.dict, file = "trump_dict.RData")
}

# breaks a data frame of tweets into a data frame of words
breakOutWords <- function(df, include.source = FALSE) {
  reg <- "([^A-Za-z\\d#@']|'(?![A-Za-z\\d#@]))"
  
  all.words <- df %>%
    mutate(text = str_replace_all(text, "https://t.co/[A-Za-z\\d]+|&amp;", "")) %>%
    unnest_tokens(word, text, token = "regex", pattern = reg) %>%
    filter(!word %in% stop_words$word, str_detect(word, "[a-z]")) # drop stop words
  
  if (include.source == TRUE) {
    select(all.words, id, word, trump)
  } else {
    select(all.words, id, word)
  }
  return(all.words)
}

keepModelVars <- function(df, include.label = FALSE) {
  if(include.label == TRUE) {
    features <- c(MODEL_FEATURES, "trump")
  } else {
    features <- MODEL_FEATURES
  }
  out <- df %>% select(one_of(features))
  return(out)
}


# Make Predictions for all tweets (up to 50) since last.id ---------------------------

predictTweets <- function(last.id) {
  tweets <- tbl_df(map_df(userTimeline("realDonaldTrump", n = 50, sinceID = last.id), as.data.frame))
  tweets <- addFeatures(tweets)
  tweets <- filter(tweets, has.quotes == 0, isRetweet == FALSE)
  model_data <- keepModelVars(tweets)
  
  load("model.RData") # load model1
  message("GENERATING PREDICTIONS")
  preds <- predict(model1, model_data, type = "response")
  out <- data.frame(tweets$id, preds)
  colnames(out) <- c("id", "prediction")
  return(out)
}
