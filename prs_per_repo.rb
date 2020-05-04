require_relative 'sprint_statistics'
require_relative 'sprint'
require 'more_core_extensions/core_ext/array/element_counts'
require 'yaml'
require 'optimist'

class PrsPerRepo
  attr_reader :opts, :config, :output_file, :sprint

  def initialize(opts)
    @opts = opts
    config_file = opts[:config_file]
    @config = YAML.load_file(config_file)

    @output_file = opts[:output_file] || "prs_per_repo.csv"

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
      STDERR.puts "invalid sprint <#{sprint_given}> specified"
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
    results = stats.client.search_issues(query)
puts "github query=#{query.inspect} returned #{results.total_count} items"
#puts "query results=#{results.inspect}"
    results.items
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

  def remaining_open(repo)
    execute_query_in_repo_or_org(repo, "type:pr state:open created:<=#{@sprint.ended_iso8601}")
  end

  def closed_after_sprint(repo)
    execute_query_in_repo_or_org(repo, "type:pr state:closed created:<=#{@sprint.ended_iso8601} closed:>#{@sprint.ended_iso8601}")
  end

  def closed_during_sprint_search_query
    "type:pr state:closed created:<=#{@sprint.ended_iso8601} closed:#{@sprint.range_iso8601}"
  end

  def closed_during_sprint(repo)
    execute_query_in_repo_or_org(repo, closed_during_sprint_search_query)
  end

  def closed_merged_during_sprint(repo)
    execute_query_in_repo_or_org(repo, "is:merged #{closed_during_sprint_search_query}")
  end

  def closed_unmerged_during_sprint(repo)
    execute_query_in_repo_or_org(repo, "is:unmerged #{closed_during_sprint_search_query}")
  end

  def created_during_sprint(repo)
    execute_query_in_repo_or_org(repo, "type:pr created:#{@sprint.range_iso8601}")
  end

  LABELS  = ["bug", "enhancement", "developer", "documentation", "performance", "refactoring", "technical debt", "test"]

  def process_repo(repo)
    puts "Analyzing Repo: #{repo}"

    stats = {}
    stats[:prs]    = {}
    stats[:counts] = {}

    opened                  = created_during_sprint(repo)
    stats[:prs][:opened]    = opened.collect(&:number).sort
    stats[:counts][:opened] = opened.length

    still_open = remaining_open(repo) + closed_after_sprint(repo)
    stats[:prs][:still_open]    = still_open.collect(&:number).sort
    stats[:counts][:still_open] = still_open.length

    closed_merged   = closed_merged_during_sprint(repo)
    closed_unmerged = closed_unmerged_during_sprint(repo)
    labels_array    = []
    closed_merged.each do |pr|
      pr.labels.each { |label| labels_array << label.name }
    end

    merged_labels_hash = labels_array.element_counts
    labels_string      = merged_labels_hash.values_at(*LABELS).collect(&:to_i).join(",")

    stats[:prs][:closed_unmerged]    = closed_unmerged.collect(&:number).sort
    stats[:counts][:closed_unmerged] = closed_unmerged.length
    stats[:prs][:closed_merged]      = closed_merged.collect(&:number).sort
    stats[:counts][:closed_merged]   = closed_merged.length
    stats[:merged_labels]   = merged_labels_hash
    puts "#{repo} stats: #{stats.inspect}"
    puts "Analyzing Repo: #{repo} completed"

    return "#{repo},#{stats[:counts][:opened]},#{stats[:counts][:closed_merged]},#{labels_string},#{stats[:counts][:still_open]}"
  end

  def process_repos
    results = @repos.collect do |repo|
      process_repo(repo)
    end

    File.open(output_file, 'w') do |f|
      f.puts "Pull Requests from: #{sprint.range.first} to: #{sprint.range.last}.  repo,#opened,#merged,#{LABELS.collect { |l| "closed_#{l}" }.join(",")},#remaining_open"
      results.each { |line| f.puts(line) }
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

      opt :output_file,
          "Output file name",
          :short    => "o",
          :default  => nil,
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

completed_in { PrsPerRepo.run(ARGV) }

