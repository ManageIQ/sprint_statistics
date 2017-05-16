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

labels  = ["bug", "enhancement", "developer", "documentation", "performance", "refactoring", "technical debt", "test", ]
results = []
repos_to_track.sort.each do |repo|
  puts "Collecting pull_requests for: #{repo}"
  prs                = stats.pull_requests(repo, :state => :all, :since => sprint_range.first.iso8601)
  closed             = prs.select { |pr| sprint_range.include?(pr.closed_at) }
  closed_labels_hash = closed.each_with_object([]) { |pr, arr| pr.labels.each { |label| arr << label.name } }.element_counts
  opened             = prs.select { |pr| sprint_range.include?(pr.created_at) }
  prs_remaining_open = stats.raw_pull_requests(repo, :state => :open).length
  labels_string      = closed_labels_hash.values_at(*labels).collect(&:to_i).join(",")
  results << "#{repo},#{opened.length},#{closed.length},#{labels_string},#{prs_remaining_open}"
end

File.open('prs_per_repo.csv', 'w') do |f|
  f.puts "Pull Requests from: #{sprint_range.first} to: #{sprint_range.last}.  repo,#opened,#closed,#{labels.collect { |l| "closed_#{l}" }.join(",")},#remaining_open"
  results.each { |line| f.puts(line) }
end
