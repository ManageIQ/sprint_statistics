require 'active_support'
require 'active_support/core_ext'

class SprintStatistics
  def initialize(access_token)
    @access_token = access_token
  end

  def client
    @client ||= begin
      require 'octokit'
      Octokit::Client.new(:access_token => @access_token)
    end
  end

  def paginated_fetch(collection, *args)
    options          = args.extract_options!
    options[:page] ||= 1

    results = []
    loop do
      response = client.send(collection, *args, options)
      break if response == []
      results += response
      options[:page] += 1
    end
    results
  end

  def issues(repo, options = {})
    paginated_fetch(:issues, repo, options)
  end

  def pull_requests(repo, options = {}) # client.pull_requests doesn't honor milestone filter
    issues(repo, options).reject { |i| !i.pull_request? }
  end

  def project_names_from_org(org)
    paginated_fetch(:repositories, org).collect(&:full_name)
  end

  def raw_pull_requests(repo, options = {})
    paginated_fetch(:pull_requests, repo, options)
  end
end
