
# Add features to a data frame of tweets

addFeatures <- function(df, trump.dict) {
  tweets <- df %>%
    mutate(hour = hour(with_tz(created_at, "EST")), tweet.date = date(created_at))
  
  tweets$source <- ifelse(tweets$source == "Twitter for Android", "android", 
                          ifelse(tweets$source == "Twitter for iPhone", "iphone", "other"))
  
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
    group_by(status_id) %>%
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
  
  odds.table <- left_join(all.words, trump.dict) %>%
    group_by(status_id) %>%
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
  
  return(trump.dict)
}

# breaks a data frame of tweets into a data frame of words
breakOutWords <- function(df, include.source = FALSE) {
  reg <- "([^A-Za-z\\d#@']|'(?![A-Za-z\\d#@]))"
  
  all.words <- df %>%
    mutate(text = str_replace_all(text, "https://t.co/[A-Za-z\\d]+|&amp;", "")) %>%
    unnest_tokens(word, text, token = "regex", pattern = reg) %>%
    filter(!word %in% stop_words$word, str_detect(word, "[a-z]")) # drop stop words
  
  if (include.source == TRUE) {
    select(all.words, status_id, word, trump)
  } else {
    select(all.words, status_id, word)
  }
  return(all.words)
}


# Make Predictions for all tweets (up to 50) since last.id 

predictTweets <- function(last.id, model.and.dict, post.tweets = FALSE) {
  message("Generating predictions!")
  tweets <- get_timeline("realDonaldTrump", n = 50, since_id = last.id)
  if(nrow(tweets) == 0) {
    stop("NO NEW TWEETS - BYE!!!")
  }
  tweets <- tweets %>% select(-urls_url, -urls_t.co, -urls_expanded_url, -media_url, -media_t.co, -media_expanded_url, -media_type,
                              -mentions_screen_name, -geo_coords, -coords_coords, -bbox_coords, -hashtags, -symbols, -ext_media_url,
                              -ext_media_t.co, -ext_media_expanded_url, -mentions_user_id)
  message("Loaded", nrow(tweets), "new tweets")
  tweets <- addFeatures(tweets, model.and.dict[[1]])
  tweets <- filter(tweets, has.quotes == 0, is_retweet == FALSE)
  model_data <- keepModelVars(tweets)
  
  message("GENERATING PREDICTIONS")
  preds <- predict(model.and.dict[[2]], model_data, type = "response")
  out <- tibble(tweets$status_id, preds)
  colnames(out) <- c("id", "prediction")
  
  # Tweet out predictions
  postAllTweets(out)
}

# Generate the tweet
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

# Post every tweet in a DF of tweets 

postAllTweets <- function(preds) {
  if(nrow(preds) == 0) {
    stop("NO NEW TWEETS - BYE!!!")
  }
  for(i in 1:nrow(preds)) {
    msg <- getMessage(preds[i,])
    post_tweet(status = msg)
  }
}

retrainModel <- function() {
  classified.tweets <- readDB("training_tweets") %>% collect()
  
  # Check for any new training tweets
  mentions <- get_mentions(n = 500)
  mentions$trump <- map_int(mentions$text, getClass)
  new.feedback <- mentions %>%
    select(status_quoted_status_id, trump) %>%
    filter(!is.na(trump), !is.na(status_quoted_status_id)) %>%
    filter(!status_quoted_status_id %in% classified.tweets$status_id)
  
  if(nrow(new.feedback) == 0) {
    message("NO NEW TRAINING DATA!")
  } else {
    message(paste("COOL! RETRAINING MODEL!", nrow(new.feedback), "NEW LABELED TWEETS"))
    new.tweets <- lookup_statuses(new.feedback$status_quoted_status_id) %>%
      select(-urls_url, -urls_t.co, -urls_expanded_url, -media_url, -media_t.co, -media_expanded_url, -media_type,
             -mentions_screen_name, -geo_coords, -coords_coords, -bbox_coords, -hashtags, -symbols, -ext_media_url,
             -ext_media_t.co, -ext_media_expanded_url, -mentions_user_id) %>%
      inner_join(new.feedback, by = c("status_id" = "status_quoted_status_id"))
      
    updateDB("training_tweets", new.tweets, append = TRUE)
    classified.tweets <- classified.tweets %>%
      bind_rows(new.tweets)
  }
  
  training.tweets <- unique(classified.tweets)
  
  trump.dict <- updateTrumpDict(training.tweets, cutoff = 1)
  
  tweets <- addFeatures(training.tweets, trump.dict)
  tweets <- filter(tweets, has.quotes == 0, is_retweet == FALSE)
  
  tweets <- keepModelVars(tweets, include.label = TRUE)
  tweets <- tweets[complete.cases(tweets), ]
  
  model1 <- gam(trump ~ s(hour, 2) + has.pic.link + trust + fear + negative + sadness + anger + 
                  surprise + positive + disgust + joy + anticipation + num.words + display_text_width + user.score,
                family = binomial(),
                data = tweets)
  return(list(trump.dict, model1))
}