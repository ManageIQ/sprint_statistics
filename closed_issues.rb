MILESTONE = 47
# subtract 6 from actual Sprint milestone number for the ManageIQ/manageiq repo
ACCESS_TOKEN = "your github access token"

require_relative 'sprint_statistics'
prs = SprintStatistics.new(ACCESS_TOKEN).pull_requests("ManageIQ/manageiq", :milestone => MILESTONE, :state => "closed")

File.open('closed_issues_master_repo.csv', 'w') do |f|
    f.puts "Milestone Statistics for: #{prs.first.milestone.title}"
    f.puts "NUMBER,TITLE,AUTHOR,ASSIGNEE,LABELS"
    prs.each do |i|
    	f.puts "#{i.number},#{i.title},#{i.user.login},#{i.assignee && i.assignee.login},#{i.labels.collect(&:name).join(" ")}"
    end
end
