require 'active_support'
require 'active_support/core_ext'

class SprintStatistics
  def initialize(access_token, milestone = nil)
    @access_token = access_token
    @milestone    = milestone
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

  def results
    paginated_fetch(:issues, "ManageIQ/manageiq", :milestone => @milestone, :state => "closed")
  end
end
