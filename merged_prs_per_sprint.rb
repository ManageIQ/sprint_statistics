require_relative 'sprint_statistics'
require_relative 'sprint'
require 'yaml'
require 'optimist'

class MergedPrs
  attr_reader :config, :config_file, :output_file, :sprint
  REPO_LJUST_LENGTH = 50

  def initialize(opts)
    @sprint = sprint_boundaries(opts)
    exit if @sprint.nil?

    @config_file = opts[:config_file]
    @config = YAML.load_file(@config_file)

    @output_file = opts[:output_file] || "merged_prs_per_sprint_#{@sprint.number}.md"
  end

  def github_api_token
    @github_api_token ||= ENV["GITHUB_API_TOKEN"] || @config[:access_token]
  end

  def stats
    @stats ||= SprintStatistics.new(github_api_token)
  end

  def priorities
    @priorities ||= begin
      @config.dig(:priority).tap do |priority|
        priority.each_with_index { |p, idx| p[:index] = idx }
      end
    end
  end

  def user_filters
    @user_filters ||= (@config.dig(:filters, :users) || []).map(&:downcase)
  end

  def label_filters
    @label_filters ||= @config.dig(:filters, :labels) || []
  end

  def additional_repos
    Array(@config[:additional_repos])
  end

  def excluded_repo?(repo_name)
    return true if excluded_repos.include?(repo_name)

    return !included_repos.include?(repo_name) if included_repos.present?

    false
  end

  def excluded_repos
    @excluded_repos ||= Array(@config[:excluded_repos])
  end

  def included_repos
    @included_repos ||= Array(@config[:included_repos])
  end

  def filters_match?(pr)
    return true if user_filters.include?(pr.user.login.downcase)
    return true unless (label_filters & pr.labels.collect(&:name)).blank?

    false
  end

  def filter_repo_prs?(fq_repo_name)
    return false if user_filters.blank? && label_filters.blank?

    !@config.dig(:filters, :non_filtered_repos).include?(fq_repo_name)
  end

  def prioritize_prs(prs)
    prs.each do |pr|
      priority = priorities.detect { |p| pr.label_names.include?(p[:label]) }
      pr.priority, pr.category = if priority
                                   [priority[:index], priority[:prefix]]
                                 else
                                   [priorities.count, nil]
                                 end
    end.sort_by(&:priority)
  end

  def format_title(pr)
    "#{pr.title} #{pr.pull_request.html_url}"
  end

  def repo_sprint_prs(fq_repo_name)
    params = {:state => "closed", :sort => 'closed_at', :direction => 'desc'}

    since = @sprint.range.begin.in_time_zone("US/Pacific").iso8601
    prs = stats.pull_requests(fq_repo_name, params.merge(:since => since)).select do |pr|
      @sprint.range.include?(pr.updated_at.to_date)
    end

    prs.each { |pr| pr.label_names = pr.labels.collect(&:name) }
    prs
  end

  def fetch_org_prs
    Hash.new { |h, k| h[k] = [] }.tap do |repos|
      result = stats.client.search_issues("is:public user:#{@config[:github_organization]} merged:#{sprint_range}")

      puts "Total merged PRs for Organization #{@config[:github_organization]}: #{result.total_count} (unfiltered count)"

      result.items.each do |pr|
        repo_name = File.join(pr.repository_url.split(File::SEPARATOR).last(2))
        next if excluded_repo?(repo_name)

        pr.label_names = pr.labels.collect(&:name)
        repos[repo_name] << pr
      end
    end
  end

  def sprint_range
    "#{@sprint.range.begin.iso8601}..#{sprint.range.end.iso8601}"
  end

  def write_stdout_and_file(f, line)
    puts line
    f.puts line
  end

  def fetch_repo_prs(fq_repo_name, prs)
    if filter_repo_prs?(fq_repo_name)
      prs = prs.select { |pr| filters_match?(pr) }
    end

    prs
  end

  def fetch_repo_prs_parallel(repos)
    return [] if repos.empty?

    require 'parallel'

    puts "Fetching..."
    repo_prs = Parallel.map(repos, :in_threads => 8) do |fq_repo_name|
      puts "  #{fq_repo_name}"
      prs = repo_sprint_prs(fq_repo_name)
      [fq_repo_name, prs]
    end
    puts

    repo_prs
  end

  def write_repo_prs(fq_repo_name, prs, total_pr_count, f)
    f.puts('')

    puts "#{fq_repo_name.ljust(REPO_LJUST_LENGTH)}#{prs.count.to_s.rjust(2)} / #{total_pr_count}"
    f.puts "## #{format_repo_name(fq_repo_name)} #{prs.count.to_s.rjust(2)} / #{total_pr_count}"

    prs = prioritize_prs(prs)

    user_width = prs.map { |pr| pr.user.login.size }.max

    prs.each { |pr| f.puts "#{pr.category || " "}  #{pr.user.login.ljust(user_width)}  #{format_title(pr)}" }
  end

  def format_repo_name(fq_repo_name)
    "#{fq_repo_name} - https://github.com/#{fq_repo_name}/pulls?q=merged%3A#{sprint_range})"
  end

  def process_repos
    File.open(@output_file, 'w') do |f|
      puts "\n"

      repo_prs = []
      fetch_org_prs.each do |fq_repo_name, prs|
        repo_prs << [fq_repo_name, [fetch_repo_prs(fq_repo_name, prs), prs.count]]
      end

      fetch_repo_prs_parallel(additional_repos).each do |fq_repo_name, prs|
        repo_prs << [fq_repo_name, [fetch_repo_prs(fq_repo_name, prs), prs.count]]
      end

      write_stdout_and_file(f, "Sprint Statistics for: \"#{@sprint.title}\"  (#{@sprint.range})")
      write_stdout_and_file(f, "")
      puts "#{'Name'.ljust(REPO_LJUST_LENGTH)}PRs: (Selected/Total)"

      empty_repos = []
      repo_prs.sort_by(&:first).each do |fq_repo_name, (prs, total_pr_count)|
        if prs.empty?
          empty_repos << [fq_repo_name, total_pr_count]
        else
          write_repo_prs(fq_repo_name, prs, total_pr_count, f)
        end
      end

      print_empty_repos(empty_repos)
    end
    puts "\nOutput written to: #{@output_file}"
  end

  def print_empty_repos(repos)
    puts
    puts "Empty Repos: #{repos.count}    name(unfiltered PR count)"
    return if repos.empty?

    puts repos.sort_by { |a| -a.last }.collect { |name, total| "#{name}(#{total})" }.join("  ")
  end

  def self.parse(args)
    opts = Optimist.options(args) do
      banner "Usage: ruby #{$PROGRAM_NAME} [opts]\n"

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

      opt :start_date,
          "Query Start Date (format: YYYY-MM-DD)",
          :short    => "s",
          :default  => nil,
          :type     => :string,
          :required => false

      opt :end_date,
          "Query End Date   (format: YYYY-MM-DD)",
          :short    => "e",
          :default  => nil,
          :type     => :string,
          :required => false

      opt :sprint_length,
          "Sprint Length (weeks)",
          :short    => "l",
          :default  => 2,
          :type     => :integer,
          :required => false
    end

    opts
  end

  def self.run(args)
    new(parse(args)).process_repos
  end
end

def sprint_boundaries(opts)
  if opts[:start_date] || opts[:end_date]
    start_date = Date.parse(opts[:start_date]) if opts[:start_date]
    end_date   = Date.parse(opts[:end_date])   if opts[:end_date]

    # If only one date is provided set the other based on the sprint length
    start_date = end_date - opts[:sprint_length].weeks   unless start_date
    end_date   = start_date + opts[:sprint_length].weeks unless end_date
    Sprint.new("NA", start_date..end_date)
  else
    Sprint.prompt_for_sprint(3)
  end
end

def completed_in
  start_time = Time.now
  yield
  puts "Completed in #{Time.now - start_time}"
end

completed_in { MergedPrs.run(ARGV) }

