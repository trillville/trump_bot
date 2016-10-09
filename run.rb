Bundler.require

class TrumpTweet < ActiveRecord::Base
  after_save :publish_tweet, if: -> { prediction.present? && !rt_twitter_id.present? }

  def percentage
    (prediction.to_f * 100).round
  end

  private

  def publish_tweet
    rt = $twitter.update("#{percentage}% chance @realDonaldTrump himself wrote this", in_reply_to_status_id: twitter_id)
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

CSV.parse(predictions_csv.split("\n")[1..-1].join("\n"), headers: true).each do |row|
  TrumpTweet.find_or_initialize_by(twitter_id: row["id"]).update_attributes!(prediction: "prediction")
end
