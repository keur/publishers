class DailyStatsJob < ApplicationJob
  queue_as :default

  def perform
    SlackMessenger.new(
      message: total_channels,
      channel: "null"
    ).perform
  end

  def total_channels
    start_time = (Date.yesterday - 3.day).at_midnight
    end_time = (Date.today - 1.day).at_midnight

    channels = Channel.where('channels.created_at > :yesterday AND channels.created_at < :today', yesterday: start_time, today: end_time)

    counts = channels.group(:details_type).count

    format = "%F %Z"

    message = "*Publisher channel counts from #{start_time.strftime(format)} to #{end_time.strftime(format)}*\n"
    if counts.empty?
      message += "🤔 Looks likes there has been no channels added."
    else
      message += "```"
      counts.each do |x, y|
        message += "#{x.sub('ChannelDetails', '').ljust(8)} - #{y}"
        message << "\n"
      end
      message += "```\n"
    end

    message += "Here's some interesting channels that signed up yesterday"
    sorted = channels.youtube_channels.sort_by { |c| c.details.stats["subscriber_count"] || 0 }
    message += statistics(sorted.last)

    sorted = channels.twitter_channels.sort_by { |c| c.details.stats["followers_count"] || 0 }
    message += statistics(sorted.last)

    message
  end

  def statistics(channel)
    stats = channel.details.stats
    details = "#{channel.details.name} - "
    details += stats.keys.map{ |k| "#{k.titleize} - #{stats[k]}" }.join('  /  ')
    details += "#{channel.details.url}"
  end
end
