require 'active_support'
require 'active_support/core_ext'

class SprintStatistics
  def initialize(access_token, milestone_string = nil)
    @access_token = access_token
    @milestone_string = milestone_string
  end

  def find_milestone_in_repo(repo, milestone = @milestone_string)
    client.milestones(repo, :state => "all").detect { |m| m.title.start_with?(milestone) }
  end

  def current_milestone
    @current_milestone ||= find_milestone_in_repo("ManageIQ/manageiq")
  end

  def previous_milestone
    @previous_milestone ||= begin
      current_milestone_number = current_milestone.title.match(/Sprint (\d+)/)[1].to_i
      previous_milestone_number = current_milestone_number - 1
      find_milestone_in_repo("ManageIQ/manageiq", "Sprint #{previous_milestone_number}")
    end
  end

  def sprint_range
    @sprint_range ||= ((previous_milestone.due_on.utc.midnight + 1.day)..(current_milestone.due_on.utc.midnight + 1.day))
  end

  def default_repos
    @default_repos ||= project_names_from_org("ManageIQ") << "Ansible/ansible_tower_client_ruby"
  end

  def client
    @client ||= begin
      require 'octokit'
      Octokit.auto_paginate = true
      Octokit::Client.new(:access_token => @access_token)
    end
  end

  def fetch(collection, *args)
    options = args.extract_options!
    client.send(collection, *args, options)
  end

  def issues(repo, options = {})
    fetch(:issues, repo, options)
  end

  def pull_requests(repo, options = {}) # client.pull_requests doesn't honor milestone filter
    issues(repo, options).reject { |i| !i.pull_request? }
  end

  def project_names_from_org(org)
    fetch(:repositories, org).collect(&:full_name)
  end

  def raw_pull_requests(repo, options = {})
    fetch(:pull_requests, repo, options)
  end
end
