class DailyStatsJob < ApplicationJob
  queue_as :default

  def perform
    SlackMessenger.new(
      message: total_channels,
      channel: "null"
    ).perform
  end

  def total_channels
    start_time = (Date.yesterday - 1.day).at_midnight
    end_time = (Date.today - 1.day).at_midnight

    channels = Channel.where('created_at > :yesterday AND created_at < :today', yesterday: start_time, today: end_time)

    counts = channels.group(:details_type).count

    format = "%F %Z"

    message += "Publisher counts from #{start_time.strftime(format)} to #{end_time.strftime(format)}"
    counts.each do |x, y|
      message += "#{x.sub('ChannelDetails', '').ljust(10)} *#{y}*"
      message << "\n"
    end
    message
  end
end
