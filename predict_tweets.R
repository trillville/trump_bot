source("libs_constants.R")
source("functions.R")
source("keys.R")

setup_twitter_oauth(twitter_consumer,
                    twitter_consumer_secret,
                    twitter_access_token,
                    twitter_access_secret)

last.id <- 

predictions <- predictTweets(last.id)

write.csv(predictions, "predictions.csv")
