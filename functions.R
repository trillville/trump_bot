
# Load all tweets and update local data file ------------------------------------------------------------------------

loadAllTweets <- function(start.date) {
  trump.tweets <- read_csv("trump_tweets.csv", guess_max = 10000, col_types = cols(id = col_character()))
  current.max.id <- trump.tweets$id[which.max(trump.tweets$created)]
  message("loading new tweets...")
  z <- get_timeline("realDonaldTrump", n = 3200, since_id = current.max.id)
  if(nrow(z) == 0) {
    message("NO NEW TWEETS")
    return(trump.tweets)
  }
  z <- z %>% mutate(favorited = FALSE, retweeted = FALSE, truncated = FALSE) %>%
    select(text, favorited, favoriteCount = favorite_count, replyToSN = reply_to_screen_name, created = created_at, truncated, replyToSID = reply_to_status_id,
           id = status_id, replyToUID = reply_to_user_id, statusSource = source, screenName = screen_name, retweetCount = retweet_count, isRetweet = is_retweet,
           retweeted, longitude = country_code, latitude = place_name)
  trump.tweets <- rbind(trump.tweets, z)
  write_csv(trump.tweets, "trump_tweets.csv")
  return(trump.tweets)
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
  
  trump.dict <- read_csv("trump_dict.csv", guess_max = 10000)
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
  
  write_csv(trump.dict, "trump_dict.csv")
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

# Get id of last tweet we posted a prediction for

getLastTweet <- function() {
  tmp <- get_timeline("TwoTrumps", n = 300) %>%
    filter(!is.na(quoted_status_id) & is.na(mentions_user_id)) %>%
    arrange(desc(quoted_status_id))
  return(tmp$quoted_status_id[1])
}


# Make Predictions for all tweets (up to 50) since last.id 

predictTweets <- function(last.id) {
  message("Loading Tweets!")
  message("Last ID: ", last.id)
  tweets <- get_timeline("realDonaldTrump", n = 50, since_id = last.id)
  if(nrow(tweets) == 0) {
    stop("NO NEW TWEETS - BYE!!!")
  }
  message("Loaded Tweets: ", nrow(tweets))
  tweets <- tweets %>% mutate(favorited = FALSE, retweeted = FALSE, truncated = FALSE) %>%
    select(text, favorited, favoriteCount = favorite_count, replyToSN = reply_to_screen_name, created = created_at, truncated, replyToSID = reply_to_status_id,
           id = status_id, replyToUID = reply_to_user_id, statusSource = source, screenName = screen_name, retweetCount = retweet_count, isRetweet = is_retweet,
           retweeted, longitude = country_code, latitude = place_name)
  tweets <- addFeatures(tweets)
  tweets <- filter(tweets, has.quotes == 0, isRetweet == FALSE)
  model_data <- keepModelVars(tweets)
  
  load("model.RData") # load model1
  message("GENERATING PREDICTIONS")
  preds <- predict(model1, model_data, type = "response")
  out <- tibble(tweets$id, preds)
  colnames(out) <- c("id", "prediction")
  return(out)
}

pct <- function(num) {
  return(as.integer(min(99, 100 * num)))
}

probablyNot <- function(percentage) {
  return(percentage <= 50 && percentage > 0)
}

notTrumpHimself <- function(percentage) {
  return(percentage <= 50)
}

definitelyNot <- function(percentage) {
  return(percentage == 0)
}

highConfidence <- function(percentage) {
  return(percentage > 95 || percentage < 5)
}

getMessage <- function(pred) {
  percent <- pct(pred$prediction)
  url <- paste("https://twitter.com/realDonaldTrump/status/", pred$id, sep = "")
  msg <- paste(sample(PREFIX_WORDS)[1], "Donald", ifelse(highConfidence(percent), "definitely", "probably"), 
               ifelse(notTrumpHimself(percent), "had his staff write this,", "wrote this himself,"),
               ifelse(definitelyNot(percent), "under 1%", paste("a ", percent, "%", sep = "")),
               paste("chance that it was him", ifelse(highConfidence(percent), "!", "."), sep = ""),
               sample(SUFFIX_WORDS)[1], url)
  return(msg)
}

# Post every tweet in a DF of tweets --------------------------------------

postAllTweets <- function(preds) {
  if(nrow(preds) == 0) {
    stop("NO NEW TWEETS - BYE!!!")
  }
  for(i in 1:nrow(preds)) {
    msg <- getMessage(preds[i,])
    post_tweet(status = msg)
  }
}

getClass <- function(text) {
  if(length(str_which(text, "not-trump")) > 0)
    trump = 0
  else if(length(str_which(text, "trump")) > 0)
    trump = 1
  else
    trump = NA
  return(as.integer(trump))
}

retrainModel <- function() {
  trump.tweets <- loadAllTweets(START_DATE)
  classified.tweets <- read_csv("classified.csv", guess_max = 10000, col_types = cols(id = col_character()))
  
  mentions <- get_mentions(n = 500)
  mentions$trump <- map_int(mentions$text, getClass)
  feedback <- mentions %>%
    filter(!is.na(trump), !is.na(status_quoted_status_id))
  
  new.feedback.tweets <- feedback %>%
    filter(status_quoted_status_id %in% trump.tweets$id) %>%
    filter(!status_quoted_status_id %in% classified.tweets$id)
  
  if(nrow(new.feedback.tweets) == 0) {
    message("NO NEW TRAINING DATA - BYE!")
    return()
  }
  
  message(paste("COOL! RETRAINING MODEL!", nrow(new.feedback.tweets), "NEW LABELED TWEETS"))
  
  new.classified.tweets <- new.feedback.tweets %>%
    select(id = status_quoted_status_id, trump) %>%
    bind_rows(classified.tweets)
  
  write_csv(new.classified.tweets, "classified.csv")
  
  training.tweets <- new.classified.tweets %>%
    inner_join(trump.tweets)
  training.tweets <- unique(training.tweets)
  
  updateTrumpDict(training.tweets, cutoff = 1)
  
  tweets <- addFeatures(training.tweets)
  tweets <- tweets[complete.cases(tweets), ]
  tweets <- filter(tweets, has.quotes == 0, isRetweet == FALSE)
  
  tweets <- keepModelVars(tweets, include.label = TRUE)
  
  model1 <- gam(trump ~ s(hour, 2) + has.pic.link + trust + fear + negative + sadness + anger + 
                  surprise + positive + disgust + joy + anticipation + num.words + user.score,
                family = binomial(),
                data = tweets)
  
  save(model1, file = "model.RData")
}