require "csv"

Bundler.require

class TrumpTweet < ActiveRecord::Base
  after_save :publish_tweet

  def percentage
    (prediction.to_f * 100).round
  end

  def message
    @message ||= ["@realDonaldTrump probably",
      (percentage <= 50 ? "didn't" : "did"),
      "tweet this,",
      ("only" if percentage <= 50),
      "#{percentage}%".with_indefinite_article,
      "chance that it was him!",
      (percentage <= 50 ? ["Sad!", "Low Energy!"].sample : ["Tremendous!", "High Energy!"].sample)
    ].compact.join(" ")
  end

  private

  def publish_tweet
    return if rt_twitter_id || !twitter_id.present? || !prediction.present?

    puts "\n\nPOSTING TO TWITTER!"
    puts message

    rt = $twitter.update(message, in_reply_to_status_id: twitter_id)
    update_attributes!(rt_twitter_id: rt.id)
  end
end

ActiveRecord::Base.establish_connection
ActiveRecord::Base.logger = Logger.new(STDOUT)

$twitter = Twitter::REST::Client.new do |config|
  config.consumer_key        = ENV["TWITTER_CONSUMER_KEY"]
  config.consumer_secret     = ENV["TWITTER_CONSUMER_SECRET"]
  config.access_token        = ENV["TWITTER_ACCESS_TOKEN"]
  config.access_token_secret = ENV["TWITTER_ACCESS_SECRET"]
end

r_script = %x[which Rscript].chomp
predictions_command = "#{r_script} --vanilla predict_tweets.R #{TrumpTweet.last.twitter_id}"
puts "running: `#{predictions_command}`"

predictions_csv = %x[#{predictions_command}]

puts "prediction output:"
puts predictions_csv

cleaned_csv = predictions_csv.split("\n")[1..-1].join("\n")

CSV.parse(cleaned_csv, headers: true).each do |row|
  puts "predicted: #{row["id"]} has probability: #{row["prediction"]}"
  TrumpTweet.find_or_initialize_by(twitter_id: row["id"]).update_attributes!(prediction: row["prediction"])
end
