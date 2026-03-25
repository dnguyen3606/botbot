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

bot.ready do |event|
    bot.register_application_command(:birthday, "Birthday Commands") do |command|
        command.subcommand(:set, "Set your birthday") do |subcommand|
            subcommand.string('date', "Your birthday...", required: true)
        end
        command.subcommand(:list, "List upcoming birthdays")
    end
end

bot.application_command(:birthday).subcommand(:set) do |event|
    date = event.options['date']

    parsed_date = Chronic.parse(date)
    next event.respond(content: "Sorry, I'm not sure how that's a birthday.", ephemeral: true) if parsed_date.nil?

    birthdays[event.server.id] ||= {}
    birthdays[event.server.id][event.user.id] = {
        month: parsed_date.month,
        day: parsed_date.day,
        channel_id: event.server.channels.find { |c| c.name.match?(/birthday/i) }&.id || event.channel.id,
    }

    event.respond(content: "Birthday set for #{parsed_date.month}/#{parsed_date.day}", ephemeral: true)
end

bot.application_command(:birthday).subcommand(:list) do |event|
    server_birthdays = birthdays[event.server.id]
    next event.respond(content: "No birthdays set yet.", ephemeral: true) if server_birthdays.nil? || server_birthdays.empty?

    today = Date.today
    sorted_birthdays = server_birthdays.sort_by do |user_id, data|
        birthday = Date.new(today.year, data[:month], data[:day])
        birthday = birthday.next_year if birthday < today
        (birthday - today).to_i
    end
    list = sorted_birthdays.map do |user_id, data|
        "#{(bot.user(user_id)&.display_name || 'Unknown').ljust(35)} #{Date::MONTHNAMES[data[:month]]} #{data[:day]}"
    end.join("\n")

    event.respond(content: <<~MSG)
```
=============== Upcoming Birthdays ===============
#{list}
```
MSG
end

scheduler.cron('0 9 * * *', timezone: 'America/New_York') do
    today = Time.now
    birthdays.each do |servers, members|
        members.each do |user_id, data|
            if today.month == data[:month] && today.day == data[:day]
                channel = bot.channel(data[:channel_id])
                channel.send_message("<@#{user_id}>'s birthday is today! Happy birthday!")
            end
        end
    end
end

bot.run