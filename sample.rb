require './feature_flag'

class TryingThingsOut
  extend FeatureFlag

  def speak
    puts message
  end

  feature_flag :some_flag
  def message
    "You have #{message_count} new messages."
  end

  def message
    'No new messages'
  end

  feature_flag :some_flag
  def message_count
    42
  end
end

thing = TryingThingsOut.new

thing.speak

FeatureFlagSettings.enable! :some_flag
thing.speak

