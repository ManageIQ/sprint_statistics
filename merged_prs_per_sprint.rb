require_relative 'sprint_statistics'
require_relative 'date_range'
require 'yaml'

PRS_COUNT_PER_REPO = 100

@config = YAML.load_file('config.yaml')

def prereq_check

  ENV["OCTOKIT_ACCESS_TOKEN"].blank?

  if ENV["OCTOKIT_ACCESS_TOKEN"].blank?
    puts <<~ENV_VAR
    Error: Environment variable OCTOKIT_ACCESS_TOKEN is not defined.
    Please visit https://help.github.com/en/github/authenticating-to-github/creating-a-personal-access-token-for-the-command-line for steps to create a personal access token
    For additional information visit on authentication visit: https://github.com/octokit/octokit.rb#authentication

    Run: OCTOKIT_ACCESS_TOKEN=<api_token> ruby merged_prs_per_sprint.rb

    OR

    Export the environment variable in one of your scripts
    export OCTOKIT_ACCESS_TOKEN=<api_token>

    Run: ruby merged_prs_per_sprint.rb

    ENV_VAR
    exit
  end
end

def client
  @client ||= begin
    require 'octokit'
    Octokit.auto_paginate = false
    Octokit::Client.new  # Uses OCTOKIT_ACCESS_TOKEN
  end
end

def priorities
  @priorities ||= begin
    @config.dig(:priority).tap do |priority|
      priority.each_with_index { |p, idx| p[:index] = idx }
    end
  end
end

def repos_to_track
  @repos_to_track ||= begin
    organization = @config[:github_organization]
    puts "Loading Organization: #{organization}"

    stats = SprintStatistics.new(ENV["OCTOKIT_ACCESS_TOKEN"])
    repos = []
    repos += stats.default_repos unless @config[:scan_default_repos] == false
    repos += Array(@config[:additional_repos]) + Array(@config.dig(:filters, :non_filtered_repos))
    repos -= Array(@config[:excluded_repos])
    repos.uniq!
    repos
  end
end

def merged_prs(fq_repo_name, date_range)
  filters = {
    :state     => "closed",
    :sort      => 'closed_at',
    :direction => 'desc',
    :per_page => PRS_COUNT_PER_REPO,
  }

  # PRs are a type of issue.  Using issues because it returns significantly less data per-record.
  # In one test the issue returned 1/3 less properties
  client.issues(fq_repo_name, filters).each_with_object([]) do |pr, prs|
    if process_pr?(pr, fq_repo_name, date_range)
      pr.label_names = pr.labels.collect(&:name)
      prs << pr
    end
  end
end

def process_pr?(pr, fq_repo_name, date_range)
  pr.pull_request? && date_range.include?(pr.closed_at) && !changelog?(pr) &&
    client.pull_merged?(fq_repo_name, pr.number)
end

def filters_match?(pr)
  user_filters = @config.dig(:filters, :users) || []
  return true if user_filters.include?(pr.user.login)

  label_filters = @config.dig(:filters, :labels) || []
  return true unless (label_filters & pr.label_names).blank?

  false
end

def filter_repo_prs?(fq_repo_name)
  user_filters = @config.dig(:filters, :users)
  label_filters = @config.dig(:filters, :labels)

  return false if user_filters.blank? && label_filters.blank?

  !@config.dig(:filters, :non_filtered_repos).include?(fq_repo_name)
end

def prioritize_prs(prs)
  prs.each do |pr|
    priority = priorities.detect { |p| pr.label_names.include?(p[:label]) }
    pr.priority, pr.category = if priority
                                 [priority[:index], priority[:prefix]]
                               else
                                 [priorities.count, '']
                               end
  end.sort_by(&:priority)
end

def changelog?(pr)
  pr.title.downcase.start_with?("[changelog]")
end

def title_markdown(pr)
  "[#{pr.title} (##{pr.number})](#{pr&.pull_request&.html_url || pr.url})"
end

def write_stdout_and_file(f, line)
  puts line
  write_file(f, line)
end

def write_file(f, line)
  f.puts line + "<br/>"
end

def filtered_prs(date_range, fq_repo_name)
  all_prs = merged_prs(fq_repo_name, date_range)

  if filter_repo_prs?(fq_repo_name)
    prs, = all_prs.partition { |pr| filters_match?(pr) }
  else
    prs = all_prs
  end

  [prs, all_prs.count]
end

def process_repo(fq_repo_name, date_range, f)
  print "Repo: #{fq_repo_name} "
  prs, total_pr_count = filtered_prs(date_range, fq_repo_name)
  if prs.count.zero?
    puts
    return
  end

  pr_count = "(Selected/Total): (#{prs.count}/#{total_pr_count})"
  puts pr_count
  write_file(f, '')
  write_file(f, "Repo: #{fq_repo_name}  #{pr_count}")
  prioritize_prs(prs).each { |pr| f.puts "#{pr.category}, #{pr.user.login},#{title_markdown(pr)}<br/>" }
end

def process_repos(date_range)
  output_file = File.join(File.dirname(__FILE__) , "merged_prs_for #{date_range.to_s}.md")

  File.open(output_file, 'w') do |f|
    write_stdout_and_file(f, "Sprint Statistics for: #{date_range.to_s}")

    empty_repos = repos_to_track.dup.delete_if do |fq_repo_name|
      process_repo(fq_repo_name, date_range, f)
    end

    puts "\nPRs found in:\n#{(repos_to_track - empty_repos).join("\n")}"

    puts "\nEmpty Repos: #{empty_repos.count}"
    # puts "Repo List: #{empty_repos.join(", ")}"

    puts "Output available in: #{output_file}"
  end
end

def completed_in
  start_time = Time.now
  yield
  puts "Completed in #{Time.now - start_time}"
end

prereq_check
date_range = DateRange.prompt_for_range(@config)
completed_in { process_repos(date_range) }
