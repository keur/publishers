class Api::V1::Stats::ChannelsController < Api::V1::StatsController
  # (yachtcaptain23): This needs to be refactored to support the data listed in #show
  def index
  end

  require 'aws-sdk-s3'

  def s3

    sts_client = Aws::STS::Client.new(
      access_key_id: ENV['S3_PUBLISHERS_ACCESS_KEY_ID'],
      secret_access_key: ENV['S3_PUBLISHERS_SECRET_ACCESS_KEY'],
      region: ENV['S3_PUBLISHERS_BUCKET_REGION']
    )
    role_credentials = Aws::AssumeRoleCredentials.new(
      client: sts_client,
      role_arn: ENV['S3_ALEXA_ARN'],
      role_session_name: "session-name"
    )

    s3_client = Aws::S3::Client.new(credentials: role_credentials, region: ENV['S3_ALEXA_REGION'])
    s3 =Aws::S3::Resource.new(client: s3_client)

    bucket = s3.bucket(ENV['S3_ALEXA_BUCKET'])

    object = []
    bucket.objects.limit(50).each do |item|
      puts "Name:  #{item.key}"
      puts "URL:   #{item.presigned_url(:get)}"
      object << { name: item.key, url: item.presigned_url(:get) }
    end

    render json: object
  end

  def show
    channel = Channel.find(params[:id])

    case channel.details_type

      when "SiteChannelDetails"
        channel_details = SiteChannelDetails.find_by_id(channel.details_id)
        channel_type = "website"
        channel_name = channel_details.url
      when "YoutubeChannelDetails"
        channel_details = YoutubeChannelDetails.find_by_id(channel.details_id)
        channel_type = "youtube"
        channel_name = channel_details.name
      when "TwitterChannelDetails"
        channel_details = TwitterChannelDetails.find_by_id(channel.details_id)
        channel_type = "twitter"
        channel_name = channel_details.name
      when "TwitchChannelDetails"
        channel_details = TwitchChannelDetails.find_by_id(channel.details_id)
        channel_type = "twitch"
        channel_name = channel_details.name
      end

    data = {
      channel_id: channel.id,
      channel_identifier: channel_details.channel_identifier,
      channel_type: channel_type,
      name: channel_name,
      stats: channel_details.stats,
      url: channel_details.url,
      owner_id: channel.publisher.owner_identifier,
      created_at: channel.created_at.strftime("%Y-%m-%d %H:%M"),
      verified: channel.verified
    }

    render(status: 200, json: data) and return

    rescue ActiveRecord::RecordNotFound
      error_response = {
        errors: [{
          status: "404",
          title: "Not Found",
          detail: "Channel with id #{params[:channel_id]} not found"
          }]
        }

    render(status: 404, json: error_response) and return
  end

  # Returns an array of buckets of site channel ids, where each bucket is defined by total channel views
  def twitch_channels_by_view_count
    # 0 - 1000 views
    bucket_one = TwitchChannelDetails.where("stats -> 'view_count' >= ?", "0").
                                      where("stats -> 'view_count' < ?", "1000").
                                      select(:id).map {|details| details.id}

    # 1000 - 10,000 views
    bucket_two = TwitchChannelDetails.where("stats -> 'view_count' >= ?", "1000").
                                      where("stats -> 'view_count' < ?", "10000").
                                      select(:id).map {|details| details.id}
    # 10,000 - 100,000 views
    bucket_three = TwitchChannelDetails.where("stats -> 'view_count' >= ?", "10000").
                                        where("stats -> 'view_count' < ?", "100000").
                                        select(:id).map {|details| details.id}
    # >= 100,000
    bucket_four = TwitchChannelDetails.where("stats -> 'view_count' >= ?", "100000").
                                       select(:id).map {|details| details.id}

    render(json: [bucket_one, bucket_two, bucket_three, bucket_four].to_json, status: 200)
  end

  def youtube_channels_by_view_count
    # 0 - 1000 views
    bucket_one = YoutubeChannelDetails.where("stats -> 'view_count' >= ?", "0").
                                       where("stats -> 'view_count' < ?", "1000").
                                       select(:id).map {|details| details.id}

    # 1000 - 10,000 views
    bucket_two = YoutubeChannelDetails.where("stats -> 'view_count' >= ?", "1000").
                                       where("stats -> 'view_count' < ?", "10000").
                                       select(:id).map {|details| details.id}
    # 10,000 - 100,000 views
    bucket_three = YoutubeChannelDetails.where("stats -> 'view_count' >= ?", "10000").
                                         where("stats -> 'view_count' < ?", "100000").
                                         select(:id).map {|details| details.id}
    # >= 100,000
    bucket_four = YoutubeChannelDetails.where("stats -> 'view_count' >= ?", "100000").
                                        select(:id).map {|details| details.id}

    render(json: [bucket_one, bucket_two, bucket_three, bucket_four].to_json, status: 200)
  end
end
