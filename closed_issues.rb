MILESTONE = 36
ACCESS_TOKEN = "your github access token"

require_relative 'sprint_statistics'
prs = SprintStatistics.new(ACCESS_TOKEN).pull_requests("ManageIQ/manageiq", :milestone => MILESTONE, :state => "closed")

puts "Milestone Statistics for: #{prs.first.milestone.title}"
puts "NUMBER,TITLE,AUTHOR,ASSIGNEE,LABELS"
puts "--------------------------------------------------"
prs.each do |i|
  puts "#{i.number},#{i.title},#{i.user.login},#{i.assignee && i.assignee.login},#{i.labels.collect(&:name).join(" ")}"
end
