require 'discordrb'
require 'dotenv/load'
require 'rufus-scheduler'
require 'chronic'

bot = Discordrb::Commands::CommandBot.new(token: ENV['BOT_TOKEN'], intents: [:servers, :server_members, :server_messages, :direct_messages], prefix: '/')
scheduler = Rufus::Scheduler.new

# eval
bot.command(:eval, help_available: false, aliases: [:evaluate, :execute, :exec, :run]) do |event, *code|
  next unless event.user.id == 271794547271401472

  begin
    eval code.join(' ')
  rescue StandardError => error
    "An error occured, coding skill issue."
    event.user.pm(error.message)
  end
end

# birthday
birthdays = {}

bot.command(:set_birthday, aliases: [:birthday, :mybirthday]) do |event, *text|
    parsed_date = Chronic.parse(*text.join(' '))
    next "Sorry, I'm not sure how that's a birthday." if parsed_date.nil?

    birthdays[event.user.id] = {
        month: parsed_date.month,
        day: parsed_date.day,
        channel_id: event.server.channels.find { |c| c.name == 'birthday' }&.id || event.channel.id,
    }
    "Birthday set for #{parsed_date.month}/#{parsed_date.day}."
end

scheduler.cron('0 0 * * *') do
    today = Time.now
    birthdays.each do |user_id, data|
        if today.month == data[:month] && today.day == data[:day]
            channel = bot.channel(data[:channel_id])
            channel.send_message("<@#{user_id}>'s birthday is today! Happy birthday!")
        end
    end
end

bot.run