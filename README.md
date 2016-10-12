# A Tale of Two Trumps
Inspired by [Dave Robinson's](https://github.com/dgrtwo/dgrtwo.github.com/blob/master/_R/2016-08-09-trump-tweets.Rmd) great post, we put together a [bot](https://twitter.com/TwoTrumps) that predicts the TRUE author of the many colorful tweets spouting out from the @realdonaldtrump twitter handle. ENJOY!

This program scrapes Donald’s twitter account for any new tweets since the last time it was run, and retweets any original content (retweets and quotes are filtered out), using a simple logistic regression to estimate the probability that he (as opposed to someone from his staff) was the true author. 

The model was built in R, using ~2000 randomly selected tweets from the past year as training data, which were manually classified by a team of hapless volunteers. As you may be aware, Donald almost always tweets from his Android device, while his staff typically tweet from iPhones. We decided to build a training dataset using manually classified tweets instead of this simple rule (or an unsupervised  algorithm) because we wanted the predictions to agree with and validate the initial human reaction. We do use the device as a feature in the model (and it weighs heavily on the prediction), so one could think of this model as assigning a prior probability based on the device, and then adjusting that classification based on how much the tweet sounds like him. Is he tweeting a link to the livestream of one of his rallies from an Android? Probably not him! ~~Excoriating~~ Bigly insulting the Republican Speaker of the House from an iPhone? Might be him! 

Does this make sense? Probably not! But let’s be honest, neither does building a twitter bot that only follows Donald Trump.

The twitter posting bot was built in Ruby, and we used a scheduler on Heroku to run the script (`bundle exec ruby run.rb`) every 10 minutes.

TODOs:
* Build a fun dashboard that lets folks see, graphically, the main factors leading to a particular classification decision
* Migrate all of the .RData files to the Heroku Postgres database
* Apply some topic modeling methods, such as ATM or LDA, to monitor trends and/or improve the classifier 
