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

  def issues(repo, options)
    paginated_fetch(:issues, repo, options)
  end

  def pull_requests(repo, options)
    issues(repo, options).reject { |i| !i.pull_request? }
  end
end
