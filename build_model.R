source("libs_constants.R")
source("functions.R")


# Set up Model Data ---------------------------------------------------------------

trump.tweets <- loadAllTweets(START_DATE)

classified.tweets <- read_csv("classified.csv")
classified.tweets <- unique(classified.tweets)

training.tweets <- left_join(trump.tweets, classified.tweets) %>%
  filter(!is.na(trump))

updateTrumpDict(training.tweets, cutoff = 1)

tweets <- addFeatures(training.tweets)

# Modeling -------------------------------------------------------------------

tweets <- tweets[complete.cases(tweets), ]
tweets <- filter(tweets, has.quotes == 0, isRetweet == FALSE)

# Feature Selection

FEATURE_SELECTION <- FALSE
if (FEATURE_SELECTION == TRUE) {
  all.x <- select(tweets, hour, has.pic.link, trust, fear, negative, source, 
                  sadness, anger, surprise, positive, disgust, joy, anticipation,
                  num.words, user.score)
  all.y <- tweets$trump
  library(Boruta)
  bor.results <- Boruta(all.x,
                        all.y,
                        maxRuns = 500,
                        doTrace = 2)
}

# LOGISTIC REGRESSION

# train <- sample(nrow(tweets), nrow(tweets)/2)
tweets <- keepModelVars(tweets, include.label = TRUE)

model1 <- gam(trump ~ s(hour, 2) + has.pic.link + trust + fear + negative + sadness + anger + 
                surprise + positive + disgust + joy + anticipation + num.words + user.score,
              family = binomial(),
              data = tweets)

# probs <- predict(model1, tweets[-train, ], type = "response")
# preds <- ifelse(probs > 0.5, 1, 0)
# table(preds, tweets$trump[-train])

save(model1, file = "model.RData")

# Unused Models -----------------------------------------------------------

# x.vars <- as.matrix(select(tweets, hour, has.quotes, has.pic.link, trust, fear, negative, sadness,
#                            anger, surprise, positive, disgust, joy, anticipation, num.words, user.score))
# y.var <- as.factor(tweets$trump)
# train <- sample(nrow(tweets), nrow(tweets)/2)

# # XGBOOST
# library(xgboost)
# xgb.x <- as.matrix(select(tweets, hour, has.quotes, has.pic.link, trust, fear, negative, sadness, 
#                 anger, surprise, positive, disgust, joy, anticipation))
# xgb.y <- tweets$trump
# 
# model3 <- xgboost(data = xgb.x[train, ], label = xgb.y[train], objective = "binary:logistic", eta = 0.01, nrounds = 1000)
# probs2 <- predict(model3, xgb.x[-train, ])


# RIDGE
# cv2 <- cv.glmnet(x = xgb.x[train, ], y = xgb.y[train], type.measure = "class", family = "binomial", alpha = 0)
# model5 <- glmnet(x = xgb.x[train, ], y = xgb.y[train], family = "binomial", alpha = 0, lambda = 0.06273243)
# probs <- predict(model5, xgb.x[-train, ], type = "response")
# preds <- ifelse(probs > 0.5, 1, 0)

# RANDOMFOREST
# library(randomForest)
# model2 <- randomForest(x = x.vars[train, ], y = y.var[train], xtest = x.vars[-train, ], ytest = y.var[-train])
# 
# preds <- model2$votes[, 2]
# table(preds, tweets$trump[-train])
# 
# 
# # LASSO
# library(glmnet)
# #cv1 <- cv.glmnet(x = xgb.x[train, ], y = xgb.y[train], type.measure = "class", family = "binomial", alpha = 1)
# model3 <- glmnet(x = x.vars[train, ], y = y.var[train], family = "binomial", alpha = 1, lambda = 0.02911781)
# 
# probs1 <- predict(model1, tweets[-train, ], type = "response")
# probs2 <- model2$votes[, 2]
# probs3 <- predict(model3, x.vars[-train, ], type = "response")
# 
# all.probs <- cbind(probs1, probs2, probs3)
# 
# # geometric mean
# probs <- rowProds(all.probs)^(1/ncol(all.probs))
# probs <- rowMeans(all.probs)
# preds <- ifelse(probs > 0.5, 1, 0)
# table(preds, y.var[-train])

