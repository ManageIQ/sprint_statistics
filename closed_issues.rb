ACCESS_TOKEN = "your github access token"
MILESTONE    = "Sprint 58 Ending Apr 10, 2017"
ORGANIZATION = "ManageIQ"
PROJECT      = "manageiq"

require_relative 'sprint_statistics'
fq_repo   = File.join(ORGANIZATION, PROJECT)
ss        = SprintStatistics.new(ACCESS_TOKEN, MILESTONE)
milestone = ss.find_milestone_in_repo(fq_repo)
prs       = ss.pull_requests(fq_repo, :milestone => milestone[:number], :state => "closed")

File.open("closed_issues_#{PROJECT}_repo.csv", 'w') do |f|
  f.puts "Milestone Statistics for: #{prs.first.milestone.title}"
  f.puts "NUMBER,TITLE,AUTHOR,ASSIGNEE,LABELS,CLOSED AT,CHANGELOGTEXT"
  prs.each do |i|
    i.changelog = "#{i.title} [(##{i.number})](#{i.pull_request.html_url})"
    f.puts "#{i.number},#{i.title},#{i.user.login},#{i.assignee && i.assignee.login},#{i.labels.collect(&:name).join(" ")},#{i.closed_at},#{i.changelog}"
  end
end
