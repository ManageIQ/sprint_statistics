ACCESS_TOKEN = "your github access token"

require_relative 'sprint_statistics'

def stats
  @stats ||= SprintStatistics.new(ACCESS_TOKEN)
end

def most_recent_monday
  @most_recent_monday ||= begin
    time = Time.now.utc.midnight
    loop do
      break if time.monday?
      time -= 1.day
    end
    time
  end
end

def sprint_range
  @sprint_range ||= ((most_recent_monday - 2.weeks)..most_recent_monday)
end

def repos_to_track
  stats.project_names_from_org("ManageIQ").to_a + ["Ansible/ansible_tower_client_ruby"]
end


results = []
(repos_to_track - ["ManageIQ/manageiq"]).sort.each do |repo| # manageiq is huge, please get its details from closed_issues.rb
  puts "Collecting pull_requests closed for: #{repo}"
  prs = stats.pull_requests(repo, :state => "closed").select { |pr| sprint_range.include?(pr.closed_at) }
  results << "#{repo},#{prs.length}"
end

File.open('closed_prs_per_repo.csv', 'w') do |f|
  f.puts "Pull Requests closed from: #{sprint_range.first} to: #{sprint_range.last}"
  results.each { |line| f.puts(line) }
end
