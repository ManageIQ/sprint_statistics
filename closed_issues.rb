MILESTONE = 36
ACCESS_TOKEN = "your github access token"

require_relative 'sprint_statistics'
results = SprintStatistics.new(ACCESS_TOKEN, MILESTONE).results

# Reject issues that are not Pull Requests
results.reject { |i| !i.pull_request? }

puts "Milestone Statistics for: #{results.first.milestone.title}"
puts "NUMBER,TITLE,AUTHOR,ASSIGNEE,LABELS"
puts "--------------------------------------------------"
results.each do |i|
  puts "#{i.number},#{i.title},#{i.user.login},#{i.assignee && i.assignee.login},#{i.labels.collect(&:name).join(" ")}"
end
