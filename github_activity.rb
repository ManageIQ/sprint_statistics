#!/usr/bin/env ruby

require "bundler/inline"
gemfile do
  source "https://rubygems.org"
  gem "activesupport"
  gem "more_core_extensions", :require => false
  gem "multi_repo", :require => "multi_repo/cli"
  gem "octokit"
  gem "optimist"
end

require_relative 'sprint_statistics'
require_relative 'sprint'
require 'more_core_extensions/core_ext/array/element_counts'
require 'yaml'

class GithubActivity
  attr_reader :opts, :config, :sprint

  def initialize(opts)
    @opts = opts
    config_file = opts[:config_file]
    @config = YAML.load_file(config_file)

    repo_given  = opts[:repo_slug_given] ? opts[:repo_slug] : config[:repo_slug]
    @repos      = repo_given ? Array(repo_given) : stats.default_repos.sort
    @github_org = repo_given ? "" : "ManageIQ"
    @sprint     = get_sprint(opts)
  end

  def get_sprint(opts)
    sprint_given = opts[:sprint_given] ? opts[:sprint] : config[:sprint]

    return Sprint.prompt_for_sprint(3) unless sprint_given

    sprint = (sprint_given == 'last') ? Sprint.last_completed : Sprint.create_by_sprint_number(sprint_given.to_i)
    if sprint.nil?
      $stderr.puts "ERROR: invalid sprint <#{sprint_given}> specified"
      exit
    end
    sprint
  end

  def github_api_token
    @github_api_token ||= ENV["GITHUB_API_TOKEN"] || @config[:access_token]
  end

  def stats
    @stats ||= SprintStatistics.new(github_api_token)
  end

  def repo_in_org?(repo, org)
    repo.split('/').first == org
  end

  def execute_query(query)
    begin
      results = stats.client.search_issues(query)
      puts "GitHub query=#{query.inspect} returned #{results.total_count} items".light_black
      #puts "query results=#{results.inspect}"
      results.items
    rescue Octokit::TooManyRequests => err
      retry_time = 60
      $stderr.puts "GitHub API rate limit exceeded. Retrying in #{retry_time} seconds.".light_yellow
      sleep retry_time
      retry
    end
  end

  def cached_execute_query(query)
    @query_cache        ||= {}
    @query_cache[query] ||= execute_query(query)
    @query_cache[query]
  end

  def execute_query_in_repo_or_org(repo, query)
    if repo_in_org?(repo, @github_org)
      results = cached_execute_query "org:#{@github_org} #{query}"
      results.select { |pr| pr.repository_url.end_with?(repo) }
    else
      cached_execute_query "repo:#{repo} #{query}"
    end
  end

  def remaining_open_query
    "state:open created:<=#{@sprint.ended_iso8601}"
  end

  def prs_remaining_open(repo)
    execute_query_in_repo_or_org(repo, "type:pr #{remaining_open_query}")
  end

  def issues_remaining_open(repo)
    execute_query_in_repo_or_org(repo, "type:issue #{remaining_open_query}")
  end

  def closed_after_sprint_query
    "state:closed created:<=#{@sprint.ended_iso8601} closed:>#{@sprint.ended_iso8601}"
  end

  def prs_closed_or_merged_after_sprint(repo)
    execute_query_in_repo_or_org(repo, "type:pr #{closed_after_sprint_query}")
  end

  def issues_closed_after_sprint(repo)
    execute_query_in_repo_or_org(repo, "type:issue #{closed_after_sprint_query}")
  end

  def closed_during_sprint_search_query
    "state:closed created:<=#{@sprint.ended_iso8601} closed:#{@sprint.range_iso8601}"
  end

  def prs_closed_during_sprint(repo)
    execute_query_in_repo_or_org(repo, "type:pr #{closed_during_sprint_search_query}")
  end

  def issues_closed_during_sprint(repo)
    execute_query_in_repo_or_org(repo, "type:issue #{closed_during_sprint_search_query}")
  end

  def prs_merged_during_sprint(repo)
    execute_query_in_repo_or_org(repo, "type:pr is:merged #{closed_during_sprint_search_query}")
  end

  def prs_closed_during_sprint(repo)
    execute_query_in_repo_or_org(repo, "type:pr is:unmerged #{closed_during_sprint_search_query}")
  end

  def created_during_sprint_query
    "created:#{@sprint.range_iso8601}"
  end

  def prs_created_during_sprint(repo)
    execute_query_in_repo_or_org(repo, "type:pr #{created_during_sprint_query}")
  end

  def issues_created_during_sprint(repo)
    execute_query_in_repo_or_org(repo, "type:issue #{created_during_sprint_query}")
  end

  LABELS  = ["bug", "enhancement", "developer", "documentation", "performance", "refactoring", "technical debt", "test"]

  def process_prs(repo)
    result = {}
    counts = {}

    prs_created = prs_created_during_sprint(repo)
    result['created'] = prs_created.collect(&:number).sort
    counts['created'] = prs_created.length

    prs_still_open = prs_remaining_open(repo) + prs_closed_or_merged_after_sprint(repo)
    result['still_open'] = prs_still_open.collect(&:number).sort
    counts['still_open'] = prs_still_open.length

    prs_closed = prs_closed_during_sprint(repo)
    result['closed'] = prs_closed.collect(&:number).sort
    counts['closed'] = prs_closed.length

    prs_merged   = prs_merged_during_sprint(repo)
    result['merged'] = prs_merged.collect(&:number).sort
    counts['merged'] = prs_merged.length

    result['merged_labels'] = prs_merged.flat_map { |pr| pr.labels.collect(&:name) }.element_counts.sort.to_h

    result['counts'] = counts
    result
  end

  def process_issues(repo)
    result = {}
    counts = {}

    issues_created = issues_created_during_sprint(repo)
    result['created'] = issues_created.collect(&:number).sort
    counts['created'] = issues_created.length

    issues_still_open = issues_remaining_open(repo) + issues_closed_after_sprint(repo)
    result['still_open'] = issues_still_open.collect(&:number).sort
    counts['still_open'] = issues_still_open.length

    issues_closed = issues_closed_during_sprint(repo)
    result['closed'] = issues_closed.collect(&:number).sort
    counts['closed'] = issues_closed.length

    result['counts'] = counts
    result
  end

  def process_repo(repo)
    puts "Analyzing Repo: #{repo}"

    stats = {}
    stats['repo_slug'] = repo
    stats['repo_url']  = "http://github.com/#{repo}"
    stats['prs']       = process_prs(repo)
    stats['issues']    = process_issues(repo)

    puts "#{repo} stats: #{stats.inspect}"
    puts "Analyzing Repo: #{repo} completed"

    stats
  end

  def process_repos
    stats = @repos.collect do |repo|
      process_repo(repo)
    end

    write_yaml(stats)
    write_csv(stats)
  end

  def output_file(output_type)
    "sprint_#{sprint.number}.#{output_type}"
  end

  def write_yaml(stats)
    File.write(output_file("yaml"), stats.to_yaml)
  end

  def write_csv(stats)
    File.open(output_file("csv"), 'w') do |f|
      f.puts "repo,opened,merged,#{LABELS.collect { |l| "closed_#{l}" }.join(",")},remaining_open"
      stats.each do |stat|
        labels_string = stat['prs']['merged_labels'].values_at(*LABELS).collect(&:to_i).join(",")
        line = "#{stat['repo_slug']},#{stat['prs']['counts']['created']},#{stat['prs']['counts']['merged']},#{labels_string},#{stat['prs']['counts']['still_open']}"
        f.puts(line)
      end
    end
  end

  def self.parse(args)
    opts = Optimist.options(args) do
      banner "Usage: ruby #{$PROGRAM_NAME} [opts]\n"

      opt :sprint,
          "Sprint",
          :short    => "s",
          :default  => nil,
          :type     => :string,
          :required => false

      opt :repo_slug,
          "Repo Slug Name (e.g. ManageIQ/manageiq)",
          :short    => "r",
          :default  => nil,
          :type     => :string,
          :required => false

      opt :config_file,
          "Config file name",
          :short    => "c",
          :default  => "config.yaml",
          :type     => :string,
          :required => false
    end

    opts
  end

  def self.run(args)
    new(parse(args)).process_repos
  end
end

def completed_in
  start_time = Time.now
  yield
  puts "Completed in #{Time.now - start_time}"
end

completed_in { GithubActivity.run(ARGV) }
