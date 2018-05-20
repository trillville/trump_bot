source("libs_constants.R")
source("functions.R")

# Update DB?
message("Trying to update DB")
source("test_db")

# Retrain model - capturing any new feedback tweets since the last time the model was retrained
retrainModel()

# Get latest tweet
last.tweet <- getLastTweet()

# Generate model scores for new trump tweets
predictions <- predictTweets(last.id)

# Tweet out predictions
postAllTweets(predictions)

# Save predictions (TODO: switch to postgres)?
write.csv(predictions, "predictions.csv")

