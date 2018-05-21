
readDB <- function(table_name) {
  return(tbl(DB_CON, table_name))
}

updateDB <- function(table_name, new_df, append = TRUE, overwrite = FALSE) {
  dbWriteTable(DB_CON, table_name, new_df, append = append, overwrite = overwrite)
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

getClass <- function(text) {
  if(length(str_which(text, "not-trump")) > 0)
    trump = 0
  else if(length(str_which(text, "trump")) > 0)
    trump = 1
  else
    trump = NA
  return(as.integer(trump))
}