ACCESS_TOKEN = "your github access token"
MILESTONE    = "Sprint 58 Ending Apr 10, 2017"

require_relative 'sprint_statistics'
require 'more_core_extensions/core_ext/array/element_counts'

def stats
  @stats ||= SprintStatistics.new(ACCESS_TOKEN, MILESTONE)
end

def merged?(repo, number)
  stats.client.pull_request(repo, number).merged?
end

def pr_issues(repo)
  stats.pull_requests(repo, :state => :all, :since => stats.sprint_range.first.iso8601)
end

labels  = ["bug", "enhancement", "developer", "documentation", "performance", "refactoring", "technical debt", "test", ]
results = []
stats.default_repos.sort.each do |repo|
  puts "Collecting pull_requests for: #{repo}"
  milestone = stats.find_milestone_in_repo(repo)
  opened = 0
  closed_merged = []
  closed_unmerged = []
  labels_arr = []
  pr_issues(repo).each do |i|
    opened += 1 if stats.sprint_range.include?(i.created_at)

    next unless stats.sprint_range.include?(i.closed_at)

    if merged?(repo, i.number)
      closed_merged << i
      i.labels.each { |label| labels_arr << label.name }
      puts "  ERROR: #{i.html_url} is missing a Milestone!!!" if milestone && !i.milestone?
    else
      closed_unmerged << i
      puts "  ERROR: #{i.html_url} has a Milestone and shouldn't!!!" if i.milestone?
    end
  end
  prs_remaining_open = stats.raw_pull_requests(repo, :state => :open).length
  merged_labels_hash = labels_arr.element_counts
  labels_string      = merged_labels_hash.values_at(*labels).collect(&:to_i).join(",")
  results << "#{repo},#{opened},#{closed_merged.length},#{labels_string},#{prs_remaining_open}"

  puts "  Closed/Unmerged: #{closed_unmerged.collect(&:html_url).inspect}"
  puts "  Closed/Merged: #{closed_merged.collect(&:html_url).inspect}"
  puts "  Closed/Merged Labels: #{merged_labels_hash.inspect}"
end

File.open('prs_per_repo.csv', 'w') do |f|
  f.puts "Pull Requests from: #{stats.sprint_range.first} to: #{stats.sprint_range.last}.  repo,#opened,#merged,#{labels.collect { |l| "closed_#{l}" }.join(",")},#remaining_open"
  results.each { |line| f.puts(line) }
end
