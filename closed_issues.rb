MILESTONE = 36
ACCESS_TOKEN = "your github access token"

require 'active_support'
require 'active_support/core_ext'

class MiqSprintStatistics
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

results = MiqSprintStatistics.new(ACCESS_TOKEN, MILESTONE).results

# Reject issues that are not Pull Requests
results.reject { |i| !i.pull_request? }

puts "Milestone Statistics for: #{results.first.milestone.title}"
puts "NUMBER,TITLE,AUTHOR,ASSIGNEE,LABELS"
puts "--------------------------------------------------"
results.each do |i|
  puts "#{i.number},#{i.title},#{i.user.login},#{i.assignee && i.assignee.login},#{i.labels.collect(&:name).join(" ")}"
end
