# this example assumes you've created a heroku postgresql
# instance and have the app name (in this example, "rpgtestcon").

# use the heroku command-line app
# we do this as the creds change & it avoids disclosure
config <- run("heroku", c("config:get", "DATABASE_URL", "-a", "tale-of-two-trumps"))

# ^^ gets us a URL, we need the parts
pg <- httr::parse_url(config$stdout)

# use the parts from ^^
dbConnect(RPostgres::Postgres(),
          dbname = trimws(pg$path),
          host = pg$hostname,
          port = pg$port,
          user = pg$username,
          password = pg$password,
          sslmode = "require"
) -> db_con

# hook it up to dbplyr
db <- src_dbi(db_con)

# boom
db
## src:  PqConnection
## tbls:
t <- read_csv("trump_tweets.csv")
ids <- t$id
a <- lookup_statuses(ids)
b <- read_csv("classified.csv") %>% group_by(id) %>% filter(row_number(id) == 1)
training_tweets <- a %>% inner_join(b, by = c("status_id" = "id"))

copy_to(db, training_tweets, name="training_tweets", overwrite = TRUE)
