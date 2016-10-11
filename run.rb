require "csv"

Bundler.require

class TrumpTweet < ActiveRecord::Base
  after_save :publish_tweet

  def percentage
    @percentage ||= [(prediction.to_f * 100).round, 99].min
  end

  def probably_not?
    percentage <= 50 && percentage > 0
  end

  def not_trump_himself?
    percentage <= 50
  end

  def definitely_not?
    percentage.zero?
  end

  def high_confidence?
    percentage > 95 || percentage < 5
  end

  def message
    @message ||= [
      (not_trump_himself? ? ["Low Energy", "Phony", "Dopey", "Neurotic", "Lightweight", "Goofy", "Crooked", "Lyin"].sample
                     : ["Tremendous", "High Energy", "Big League"].sample),
      "@realDonaldTrump",
      (high_confidence? ? "almost certainly" : "probably"),
      (not_trump_himself? ? "had his staff write this," : "wrote this himself,"),
      (definitely_not? ? "under 1%" : "#{percentage}%".with_indefinite_article),
      "chance that it was him#{high_confidence? ? "!" : "."}",
      (not_trump_himself? ? ["Weak!", "Dummy!", "Loser!", "Bad!"].sample
                     : ["Smart!", "Winning!", "Locker room!", "AMAZING!"].sample),
      original_tweet.url
    ].compact.join(" ")
  end

  def original_tweet
    @original_tweet ||= $twitter.status(twitter_id)
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
  next if row["prediction"] == "NA"
  TrumpTweet.find_or_initialize_by(twitter_id: row["id"]).update_attributes!(prediction: row["prediction"])
end
