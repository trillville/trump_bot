Bundler.require

class TrumpTweet < ActiveRecord::Base
  after_save :publish_tweet, if: -> (t) { prediction.present? && !rt_twitter_id.present? }

  def percentage
    (prediction.to_f * 100).round
  end

  def original_tweet
    @original_tweet ||= $twitter.status(twitter_id)
  end

  def retweet
    @retweet ||= $twitter.status(rt_twitter_id)
  end

  private

  def publish_tweet
    retweet.delete if rt_twitter_id.present?
    rt = original_tweet.retweet("#{percentage}% chance @realDonaldTrump himself wrote this")
    update_attributes!(rt_twitter_id: rt.id)
  end
end

ActiveRecord::Base.establish_connection

$twitter = Twitter::REST::Client.new do |config|
  config.consumer_key        = ENV["TWITTER_CONSUMER_KEY"]
  config.consumer_secret     = ENV["TWITTER_CONSUMER_SECRET"]
  config.access_token        = ENV["TWITTER_ACCESS_TOKEN"]
  config.access_token_secret = ENV["TWITTER_ACCESS_SECRET"]
end

r_script = %x[which Rscript].chomp
predictions_csv = %x[#{r_script} --vanilla #{File.expand_path("predict_tweets.R", __FILE__)} #{TrumpTweet.last.twitter_id}]

CSV.parse(predictions_csv, headers: true).each do |row|
  TrumpTweet.find_or_initialize_by(twitter_id: row["id"]).update_attributes!(prediction: "prediction")
end
