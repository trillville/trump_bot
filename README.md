# A Tale of Two Trumps
Inspired by [Dave Robinson's](https://github.com/dgrtwo/dgrtwo.github.com/blob/master/_R/2016-08-09-trump-tweets.Rmd) great post, we put together a [bot](https://twitter.com/TwoTrumps) that predicts the TRUE author of the many colorful tweets spouting out from the @realdonaldtrump twitter handle. ENJOY!

This program scrapes Donald’s twitter account for any new tweets since the last time it was run, and retweets any original content (retweets and quotes are filtered out), using a simple logistic regression to estimate the probability that he (as opposed to someone from his staff) was the true author. 

The model was built in R, using ~2000 randomly selected tweets from the past year as training data, which were manually classified by a team of hapless volunteers. As you may be aware, Donald almost always tweets from his Android device, while his staff typically tweet from iPhones. We decided to build a training dataset using manually classified tweets instead of this simple rule (or an unsupervised  algorithm) because we wanted the predictions to agree with and validate the initial human reaction. We do use the device as a feature in the model (and it weighs heavily on the prediction), so one could think of this model as assigning a prior probability based on the device, and then adjusting that classification based on how much the tweet sounds like him. Is he tweeting a link to the livestream of one of his rallies from an Android? Probably not him! ~~Excoriating~~ Bigly insulting the Republican Speaker of the House from an iPhone? Might be him! 

Does this make sense? Probably not! But let’s be honest, neither does building a twitter bot that only follows Donald Trump.

The twitter posting bot was built in Ruby, and we used a scheduler on Heroku to run the script (`bundle exec ruby run.rb`) every 10 minutes.

For those of you that are interested, here's the summary (showing statistical significant of the various features) for the current model:

Coefficients:
                         Estimate Std. Error z value Pr(>|z|)    
(Intercept)               0.39771    0.45527   0.874   0.3823    
s(hour, 2)                0.02902    0.02595   1.118   0.2634    
has.pic.link             -0.09704    1.21685  -0.080   0.9364    
trust                     0.04548    0.26754   0.170   0.8650    
fear                      0.02642    0.35421   0.075   0.9405    
negative                 -0.05225    0.32172  -0.162   0.8710    
sourceOther              -4.09319    0.42460  -9.640   <2e-16 ***
sadness                  -0.27443    0.39115  -0.702   0.4829    
anger                     0.64118    0.34110   1.720   0.0835 .   
surprise                 -0.58931    0.35592  -1.656   0.0978 .  
positive                  0.31749    0.22646   1.402   0.1609    
disgust                  -0.02660    0.38272  -0.070   0.9446    
joy                      -0.16915    0.35832  -0.472   0.6369    
anticipation             -0.17713    0.33710  -0.525   0.5993    
num.words                 0.12614    0.06428   1.962   0.0497 *  
user.score                0.50602    0.04108  12.317   <2e-16 ***
has.pic.link:sourceOther -2.38863    1.42333  -1.678   0.0933 .  
---
Signif. codes:  0 ‘***’ 0.001 ‘**’ 0.01 ‘*’ 0.05 ‘.’ 0.1 ‘ ’ 1

TODOs:
* Build a fun dashboard that lets folks see, graphically, the main factors leading to a particular classification decision
* Migrate all of the .RData files to the Heroku Postgres database
* Apply some topic modeling methods, such as ATM or LDA, to monitor trends and/or improve the classifier 
