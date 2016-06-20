MILESTONE = 36
ACCESS_TOKEN = "your github access token"

require 'octokit'
o = Octokit::Client.new(:access_token => ACCESS_TOKEN)

results = []
page = 1

loop do
  response = o.issues("ManageIQ/manageiq", :milestone => MILESTONE, :state => "closed", :page => page)
  break if response == []
  results += response
  page += 1
end

# Reject issues that are not Pull Requests
results.reject { |i| !i.pull_request? }

puts "Milestone Statistics for: #{results.first.milestone.title}"
puts "NUMBER,AUTHOR,ASSIGNEE,LABELS"
puts "--------------------------------------------------"
results.each do |i|
  puts "#{i.number},#{i.user.login},#{i.assignee && i.assignee.login},#{i.labels.collect(&:name).join(" ")}"
end
