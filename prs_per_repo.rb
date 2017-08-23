ACCESS_TOKEN = "your github access token"
MILESTONE    = "Sprint 58 Ending Apr 10, 2017"

require_relative 'sprint_statistics'
require 'more_core_extensions/core_ext/array/element_counts'

def stats
  @stats ||= SprintStatistics.new(ACCESS_TOKEN, MILESTONE)
end

labels  = ["bug", "enhancement", "developer", "documentation", "performance", "refactoring", "technical debt", "test", ]
results = []
stats.default_repos.sort.each do |repo|
  puts "Collecting pull_requests for: #{repo}"
  prs                = stats.pull_requests(repo, :state => :all, :since => stats.sprint_range.first.iso8601)
  closed             = prs.select { |pr| stats.sprint_range.include?(pr.closed_at) }
  closed_labels_hash = closed.each_with_object([]) { |pr, arr| pr.labels.each { |label| arr << label.name } }.element_counts
  opened             = prs.select { |pr| stats.sprint_range.include?(pr.created_at) }
  prs_remaining_open = stats.raw_pull_requests(repo, :state => :open).length
  labels_string      = closed_labels_hash.values_at(*labels).collect(&:to_i).join(",")
  results << "#{repo},#{opened.length},#{closed.length},#{labels_string},#{prs_remaining_open}"
end

File.open('prs_per_repo.csv', 'w') do |f|
  f.puts "Pull Requests from: #{stats.sprint_range.first} to: #{stats.sprint_range.last}.  repo,#opened,#closed,#{labels.collect { |l| "closed_#{l}" }.join(",")},#remaining_open"
  results.each { |line| f.puts(line) }
end
