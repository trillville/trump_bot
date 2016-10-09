source("libs_constants.R")
source("functions.R")

setup_twitter_oauth(Sys.getenv("TWITTER_CONSUMER_KEY"),
                    Sys.getenv("TWITTER_CONSUMER_SECRET"),
                    Sys.getenv("TWITTER_ACCESS_TOKEN"),
                    Sys.getenv("TWITTER_ACCESS_TOKEN_SECRET"))

last.id <- commandArgs(trailingOnly=TRUE)[1] # "784216198259085312"

predictions <- predictTweets(last.id)

write.csv(predictions)
