MILESTONE = 47
# subtract 6 from actual Sprint milestone number for the ManageIQ/manageiq repo
ACCESS_TOKEN = "your github access token"

require_relative 'sprint_statistics'
prs = SprintStatistics.new(ACCESS_TOKEN).pull_requests("ManageIQ/manageiq", :milestone => MILESTONE, :state => "closed")

File.open('closed_issues_master_repo.csv', 'w') do |f|
    f.puts "Milestone Statistics for: #{prs.first.milestone.title}"
    f.puts "NUMBER,TITLE,AUTHOR,ASSIGNEE,LABELS,CLOSED AT,CHANGELOGTEXT"
    prs.each do |i|
    	i.changelog = "#{i.title} #[#{i.number}](#{i.pull_request.html_url})"
    	f.puts "#{i.number},#{i.title},#{i.user.login},#{i.assignee && i.assignee.login},#{i.labels.collect(&:name).join(" ")},#{i.closed_at},#{i.changelog}"
    end
end
