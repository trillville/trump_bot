class CreateTrumpTweets < ActiveRecord::Migration
  def change
    create_table :trump_tweets do |t|
      t.text       :twitter_id
      t.text       :tweet_text
      t.float      :prediction
      t.text       :rt_twitter_id
      t.timestamps null: false
    end
  end
end
