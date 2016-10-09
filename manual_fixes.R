library(readr)

t1 <- read_csv("C:/Users/tillm/OneDrive/Documents/twitter_bot/training/tweets_1.csv") %>%
  rename(Unsure = Unclear)
t2 <- read_csv("C:/Users/tillm/OneDrive/Documents/twitter_bot/training/tweets_2.csv") %>%
  rename(text = tweet)
t3 <- read_csv("C:/Users/tillm/OneDrive/Documents/twitter_bot/training/tweets_6.csv") %>%
  rename(text = tweet, Trump = trump, Staff = staff, Unsure = unsure)

all <- bind_rows(t1, t2, t3)
all[is.na(all)] <- 0

all <- group_by(all, text) %>%
  summarise(Trump = round(mean(Trump)), Staff = round(mean(Staff)), Unsure = round(mean(Unsure))) %>%
  filter(Trump + Staff > 0) %>%
  left_join(tweets) %>%
  select(-Unsure, -Staff, -trump)

train <- sample(nrow(all), nrow(all)/2)


model1 <- glm(Trump ~ hour + has.pic.link + trust + fear + negative + 
                sadness + anger + surprise + positive + disgust + joy + anticipation, 
              family = binomial(),
              data = all[train, ])

probs <- predict(model1, all[-train, ], type = "response")
preds <- ifelse(probs > 0.5, 1, 0)
table(preds, all$Trump[-train])


t2 <- select(tweets, id, text, trump)
write.csv(t2, "all.tweets.csv")

t1 <- read_csv("C:/Users/tillm/OneDrive/Documents/twitter_bot/training/completed.csv")
test <- left_join(t1, t2,
                  by = c("text" = "text"))

a1 <- read_csv("C:/Users/tillm/OneDrive/Documents/twitter_bot/training/classified.csv")
trump <- a1$trump

tweets <- select(tweets, -trump)
tweets <- tweets[1:1605, ]
tweets <- cbind(tweets, trump)

x.vars <- as.matrix(select(tweets, hour, has.quotes, has.pic.link, trust, fear, negative, sadness, 
                           anger, surprise, positive, disgust, joy, anticipation))
train <- sample(nrow(tweets), nrow(tweets)/2)

# TODO - replace with actual manual training results
y.var <- tweets$trump

# LOGISTIC REGRESSION
model1 <- glm(trump ~ hour + has.pic.link + negative + disgust, 
              family = binomial(),
              data = tweets[train,])

model1 <- bestglm(Xy = tmp[train, ], family = binomial(), IC = "BIC")

probs <- predict(model1, tweets[-train, ], type = "response")
preds <- ifelse(probs > 0.5, 1, 0)
table(preds, y.var[-train])








tmp <- tweets
tmp <- rename(tmp, y = trump) %>%
  select(hour, has.pic.link, trust, fear, negative, sadness, anger, surprise, positive, disgust, joy, anticipation, y)

model1 <- bestglm(Xy = tmp[train, ], family = binomial(), IC = "BIC")
