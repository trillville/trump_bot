source("libs_constants.R")
source("functions.R")

create_token(app="Tale o' Dos Trumpos",
             consumer_key = Sys.getenv("TWITTER_CONSUMER_KEY"),
             consumer_secret = Sys.getenv("TWITTER_CONSUMER_SECRET"))

last.id <- commandArgs(trailingOnly=TRUE)[1] # "784216198259085312"

predictions <- predictTweets(last.id)

write.csv(predictions, "predictions.csv")

write.csv(predictions)