require_relative 'sprint_statistics'
require_relative 'sprint'
require 'more_core_extensions/core_ext/array/element_counts'
require 'yaml'
require 'optimist'

class PrsPerRepo
  attr_reader :config, :config_file, :output_file, :sprint

  def initialize(opts)
    @sprint = find_sprint(opts[:sprint])
    if @sprint.nil?
      STDERR.puts "invalid sprint specified"
      exit
    end

    @config_file = opts[:config_file]
    @config = YAML.load_file(@config_file)

    @output_file = opts[:output_file] || "prs_per_repo.csv"
  end

  def find_sprint(sprint = nil)
    if sprint.nil?
      Sprint.prompt_for_sprint(3)
    elsif sprint == 'last'
      Sprint.last_completed
    else
      Sprint.create_by_sprint_number(sprint.to_i)
    end      
  end

  def github_api_token
    @github_api_token ||= ENV["GITHUB_API_TOKEN"] || @config[:access_token]
  end

  def stats
    @stats ||= SprintStatistics.new(github_api_token)
  end

  def merged?(repo, number)
    stats.client.pull_request(repo, number).merged?
  end

  def prs_since_sprint_start(repo)
    since = @sprint.range.begin.in_time_zone("US/Pacific").iso8601
    stats.pull_requests(repo, :state => :all, :since => since)
  end

  def open_prs(repo)
    stats.pull_requests(repo, :state => :open)
  end

  LABELS  = ["bug", "enhancement", "developer", "documentation", "performance", "refactoring", "technical debt", "test"]

  def process_repo(repo)
    puts "Collecting pull_requests for: #{repo}"
    opened = 0
    closed_merged = []
    closed_unmerged = []
    labels_arr = []
    prs_remaining_open = open_prs(repo).length

    prs_since_sprint_start(repo).each do |pr|
      next if @sprint.after_range?(pr.created_at)  # skip PRs opened after the end of the sprint

      opened += 1 if @sprint.in_range?(pr.created_at)

      if @sprint.in_range?(pr.closed_at)
        if merged?(repo, pr.number)
          closed_merged << pr
          pr.labels.each { |label| labels_arr << label.name }
        else
          closed_unmerged << pr
        end
      else
        # Add to remaining open any PRs that were closed AFTER the sprint ended
        prs_remaining_open += 1 if pr.closed_at && @sprint.after_range?(pr.closed_at)
      end
    end
    merged_labels_hash = labels_arr.element_counts
    labels_string      = merged_labels_hash.values_at(*LABELS).collect(&:to_i).join(",")

    puts "  Closed/Unmerged: #{closed_unmerged.collect(&:html_url).inspect}"
    puts "  Closed/Merged: #{closed_merged.collect(&:html_url).inspect}"
    puts "  Closed/Merged Labels: #{merged_labels_hash.inspect}"

    return "#{repo},#{opened},#{closed_merged.length},#{labels_string},#{prs_remaining_open}"
  end

  def process_repos
    results = stats.default_repos.sort.collect do |repo|
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

