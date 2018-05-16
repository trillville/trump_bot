source("libs_constants.R")
source("functions.R")

message(getwd())

last.id <- commandArgs(trailingOnly=TRUE)[1] # "784216198259085312"

predictions <- predictTweets(last.id)

write.csv(predictions, "predictions.csv")

write.csv(predictions)