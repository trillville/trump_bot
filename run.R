source("libs_constants.R")
source("functions.R")
source("utils.R")

# Connect to the DB
message("Connecting to DB!")
pg <- httr::parse_url(Sys.getenv("DATABASE_URL"))

dbConnect(RPostgres::Postgres(),
          dbname = trimws(pg$path),
          host = pg$hostname,
          port = pg$port,
          user = pg$username,
          password = pg$password,
          sslmode = "require"
) -> DB_CON

# hook it up to dbplyr
DB <- src_dbi(DB_CON)

# Retrain model - capturing any new feedback tweets since the last time the model was retrained. Also updates the dictionary
model.and.dict <- retrainModel()

# Get latest trump tweet
last.tweet <- getLastTweet()

# Generate model scores for new trump tweets (if any)
predictions <- predictTweets(last.tweet, model.and.dict, post.tweets = TRUE)

