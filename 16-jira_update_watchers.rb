# frozen_string_literal: true

load './lib/common.rb'

# TODO
# Move to common.rb -- start

# Assembla users
assembla_users_csv = "#{OUTPUT_DIR_ASSEMBLA}/report-users.csv"
@users_assembla = csv_to_array(assembla_users_csv)

@user_id_to_login = {}
@user_id_to_email = {}
@user_login_to_email = {}
@list_of_logins = {}
@users_assembla.each do |user|
  id = user['id']
  login = user['login'].sub(/@.*$/,'')
  email = user['email']
  if email.nil? || email.empty?
    email = "#{login}@example.org"
  end
  @user_id_to_login[id] = login
  @user_id_to_email[id] = email
  @user_login_to_email[login] = email
  @list_of_logins[login] = true
end

# Move to common.rb -- end

# Assembla tickets
tickets_csv = "#{OUTPUT_DIR_ASSEMBLA}/tickets.csv"
@tickets_assembla = csv_to_array(tickets_csv)

# --- Filter by date if TICKET_CREATED_ON is defined --- #
tickets_created_on = get_tickets_created_on

if tickets_created_on
  puts "\nFilter newer than: #{tickets_created_on}"
  @tickets_assembla.select! { |item| item_newer_than?(item, tickets_created_on) }
end

@total_assembla_tickets = @tickets_assembla.length
puts "\nTotal Assembla tickets: #{@total_assembla_tickets}"

# Jira tickets
tickets_jira_csv = "#{OUTPUT_DIR_JIRA}/jira-tickets.csv"
@tickets_jira = csv_to_array(tickets_jira_csv)

# TODO
# Move to common.rb -- start

@a_id_to_j_id = {}
@a_nr_to_j_key = {}
@j_id_to_j_login = {}
@tickets_jira.each do |ticket|
  assembla_id = ticket['assembla_ticket_id']
  jira_id = ticket['jira_ticket_id']
  jira_key = ticket['jira_ticket_key']
  @a_id_to_j_id[assembla_id] = jira_id
  @a_nr_to_j_key[assembla_id] = jira_key
  @j_id_to_j_login[jira_id] = ticket['reporter_name']
end

# Move to common.rb -- end

# POST /rest/api/2/issue/{issueIdOrKey}/watchers
def jira_update_watcher(issue_id, watcher, counter)
  result = nil
  user_login = watcher
  user_login.sub!(/@.*$/,'')
  user_email = @user_login_to_email[user_login]
  headers = if JIRA_SERVER_TYPE == 'hosted'
              headers_user_login(user_login, user_email)
            else
              JIRA_HEADERS_CLOUD
            end
  url = "#{URL_JIRA_ISSUES}/#{issue_id}/watchers"
  payload = "\"#{watcher}\""
  begin
    percentage = ((counter * 100) / @total_assembla_tickets).round.to_s.rjust(3)
    RestClient::Request.execute(method: :post, url: url, payload: payload, headers: headers)
    puts "#{percentage}% [#{counter}|#{@total_assembla_tickets}] POST #{url} '#{watcher}' => OK"
    result = true
  rescue RestClient::ExceptionWithResponse => e
    rest_client_exception(e, 'POST', url, payload)
  rescue => e
    puts "#{percentage}% [#{counter}|#{@total_assembla_tickets}] POST #{url} #{watcher} => NOK (#{e.message})"
  end
  result
end

@jira_updates_tickets = []

@tickets_assembla.each_with_index do |ticket, index|
  assembla_ticket_id = ticket['id']
  assembla_ticket_nr = ticket['number']
  assembla_ticket_watchers = ticket['notification_list']
  jira_ticket_id = @a_id_to_j_id[assembla_ticket_id]
  jira_ticket_key = @a_nr_to_j_key[assembla_ticket_nr]
  assembla_ticket_watchers.split(',').each do |user_id|
    next unless user_id.length.positive?
    watcher = @user_id_to_login[user_id]
    unless watcher
      puts "Unknown watcher for user_id=#{user_id}, assembla_ticket_nr=#{assembla_ticket_nr}, jita_ticket_key=#{jira_ticket_key}"
      next
    end
    result = jira_update_watcher(jira_ticket_id, watcher, index + 1)
    @jira_updates_tickets << {
      result: result.nil? ? 'NOK' : 'OK',
      assembla_ticket_id: assembla_ticket_id,
      assembla_ticket_number: assembla_ticket_nr,
      jira_ticket_id: jira_ticket_id,
      jira_ticket_key: jira_ticket_key,
      assembla_user_id: user_id,
      watcher: watcher
    }
  end
end

puts "\nTotal updates: #{@jira_updates_tickets.length}"
watchers_tickets_jira_csv = "#{OUTPUT_DIR_JIRA}/jira-tickets-watchers.csv"
write_csv_file(watchers_tickets_jira_csv, @jira_updates_tickets)