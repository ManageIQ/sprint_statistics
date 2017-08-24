require 'active_support'
require 'active_support/core_ext'

class SprintStatistics
  def initialize(access_token, milestone_string = nil)
    @access_token = access_token
    @milestone_string = milestone_string
  end

  def find_milestone_in_repo(repo)
    client.milestones(repo, :state => "all").detect { |m| m.title == @milestone_string }
  end

  def current_milestone
    @current_milestone ||= find_milestone_in_repo("ManageIQ/manageiq")
  end

  def previous_milestone
    @previous_milestone ||= begin
      current_milestone_number = current_milestone.title.match(/Sprint (\d+)/)[1].to_i
      previous_milestone_number = current_milestone_number - 1
      client.milestones("ManageIQ/manageiq", :state => "all").detect { |m| m.title.start_with?("Sprint #{previous_milestone_number}") }
    end
  end

  def sprint_range
    @sprint_range ||= ((previous_milestone.due_on.utc.midnight + 1.day)..(current_milestone.due_on.utc.midnight + 1.day))
  end

  def default_repos
    @default_repos ||= stats.project_names_from_org("ManageIQ").to_a + ["Ansible/ansible_tower_client_ruby"]
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
