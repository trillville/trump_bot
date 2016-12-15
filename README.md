# A Tale of Two Trumps
Inspired by [Dave Robinson's](https://github.com/dgrtwo/dgrtwo.github.com/blob/master/_R/2016-08-09-trump-tweets.Rmd) great post, we put together a [bot](https://twitter.com/TwoTrumps) that predicts the TRUE author of the many colorful tweets spouting out from the @realdonaldtrump twitter handle. ENJOY!

This program scrapes Donald’s twitter account for any new tweets since the last time it was run, and retweets any original content (retweets and quotes are filtered out), using a simple logistic regression to estimate the probability that he (as opposed to someone from his staff) was the true author. 

The model was built in R, using ~2000 randomly selected tweets from the past year as training data, which were manually classified by a team of hapless volunteers. As you may be aware, Donald almost always tweets from his Android device, while his staff typically tweet from iPhones. We decided to build a training dataset using manually classified tweets instead of this simple rule (or an unsupervised  algorithm) because we wanted the predictions to agree with and validate the initial human reaction. We do use the device as a feature in the model (and it weighs heavily on the prediction), so one could think of this model as assigning a prior probability based on the device, and then adjusting that classification based on how much the tweet sounds like him. Is he tweeting a link to the livestream of one of his rallies from an Android? Probably not him! ~~Excoriating~~ Bigly insulting the Republican Speaker of the House from an iPhone? Might be him! 

Does this make sense? Probably not! But let’s be honest, neither does building a twitter bot that only follows Donald Trump.

The twitter posting bot was built in Ruby, and we used a scheduler on Heroku to run the script (`bundle exec ruby run.rb`) every 10 minutes.

For those of you that are interested, here's the summary (showing statistical significant of the various features) for the current model:

| Coefficient             | z-value  | Pr(>z)   |
| ----------------------- | -------- | -------- |
| s(hour, 2)              | 1.118    | 0.382    |
| has.pic.link            | -0.080   | 0.263    |
| trust.                  | 0.170    | 0.936    |
| fear                    | 0.075    | 0.865    |
| negative                | -0.162   | 0.810    |
| sourceOther             | -9.640   | <2e-16***|
| sadness                 | -0.702   | 0.483    |
| anger                   | 1.720    | 0.085*   |
| surprise                | -1.656   | 0.098*   |
| positive                | 1.402    | 0.161    |
| disgust                 | -0.070   | 0.945    |
| joy                     | -0.472   | 0.637    |
| anticipation            | -0.525   | 0.599    |
| num.words               | 1.962    | 0.049**  |
| user.score              | 12.317   | <2e-16***|
| has.pic.link:sourceOthe | -1.678   | 0.093*   |

Signif. codes:  0.01: *** 0.05: ** 0.1: * 

TODOs:
* Build a fun dashboard that lets folks see, graphically, the main factors leading to a particular classification decision
* Migrate all of the .RData files to the Heroku Postgres database
* Apply some topic modeling methods, such as ATM or LDA, to monitor trends and/or improve the classifier 
