require "net/http"
require "json"
require "active_support/core_ext"

DEFAULT_CODECLIMATE_URL = "https://api.codeclimate.com"

class CodeClimateRequest
  def initialize
    @base_uri  = ENV["CODECLIMATE_URL"] || DEFAULT_CODECLIMATE_URL
    @api_token = ENV.fetch("CODECLIMATE_API_TOKEN")
  end

  def request(path)
    uri = URI("#{@base_uri}#{path}")
    if ENV["DEBUG"] == "1"
      STDERR.puts uri.to_s
    end
    http = Net::HTTP.new(uri.hostname, uri.port)
    http.use_ssl = uri.scheme == "https" ? true : false
    request = Net::HTTP::Get.new(uri.request_uri)
    request.set_content_type("application/vnd.api+json")
    request["Authorization"] = "Token token=#{@api_token}"
    http.request(request)
  end
end

class CodeClimate
  def self.repo_stats(repo_name)
    cc = CodeClimate.new
    repo = cc.repo_from_github_slug(repo_name)
    return {} if repo.nil?
    
    repo_id     = repo["id"]
    snapshot_id = repo["relationships"]["latest_default_branch_snapshot"]["data"]["id"]

    snapshot = cc.snapshot(repo_id, snapshot_id)
    files    = cc.files(repo_id, snapshot_id)
    issues   = cc.issues(repo_id, snapshot_id)

    issue_counts = {}
    issue_counts['total']       = issues.length
    issue_counts['complexity']  = issues.count { |issue| issue["attributes"]["categories"].include?("Complexity") }
    issue_counts['duplication'] = issues.count { |issue| issue["attributes"]["categories"].include?("Duplication") }
    issue_counts['style']       = issues.count { |issue| issue["attributes"]["categories"].include?("Style") }
    issue_counts['bug_risk']    = issues.count { |issue| issue["attributes"]["categories"].include?("Bug Risk") }

    {
      'files'  => files.length,
      'loc'    => snapshot['attributes']['lines_of_code'],
      'issues' => issue_counts,
      'rating' => snapshot['attributes']['ratings'].first['letter']
    }
  end

  def repo_from_github_slug(slug)
    query = { "github_slug" => slug }
    path = "/v1/repos?#{query.to_query}"
    response = CodeClimateRequest.new.request(path)
    response_to_data(response, path)&.first
  end

  def repo_from_id(id)
    path = "/v1/repos/#{id}"
    response = CodeClimateRequest.new.request(path)
    response_to_data(response, path)&.first
  end

  def services(repo_id)
    path = "/v1/repos/#{repo_id}/services"
    response = CodeClimateRequest.new.request(path)
    response_to_data(response, path)
  end

  def snapshot(repo_id, snapshot_id)
    path = "/v1/repos/#{repo_id}/snapshots/#{snapshot_id}"
    response = CodeClimateRequest.new.request(path)
    response_to_data(response, path)
  end

  def issues(repo_id, snapshot_id)
    multi_paged_query("/v1/repos/#{repo_id}/snapshots/#{snapshot_id}/issues")
  end

  def files(repo_id, snapshot_id)
    multi_paged_query("/v1/repos/#{repo_id}/snapshots/#{snapshot_id}/files")
  end

  private

  def multi_paged_query(base_path)
    result = []
    page_number = 0
    query = {
      "page[size]"   => 100,
      "page[number]" => page_number
    }
    
    while true
      page_number += 1
      query["page[number]"] = page_number
      path = "#{base_path}?#{query.to_query}"
      response = CodeClimateRequest.new.request(path)
      data = response_to_data(response, path)
      break if data.nil?
      result += data
    end
    
    result
  end

  def response_to_data(response, path = nil)
    data = nil

    if response.code == "200"
      parsed_response = JSON.parse(response.body)
      if parsed_response["data"].size > 0
        data = parsed_response["data"]
      else
        if ENV["DEBUG"] == "1"
          STDERR.puts "Invalid response for path=\"#{path}\": #{parsed_response.inspect}"
        end
      end
    else
      STDERR.puts "Invalid response code for path=\"#{path}\": #{response.code}"
    end
    
    data
  end
end

ALL_REPO_NAMES = [
  "ManageIQ/manageiq",
  "ManageIQ/manageiq-schema",
  "ManageIQ/manageiq-api",
  "ManageIQ/manageiq-ui-classic",
  "ManageIQ/manageiq-ui-service",
  "ManageIQ/manageiq-automation_engine",
  "ManageIQ/manageiq-content",
  "ManageIQ/manageiq-providers-amazon",
  "ManageIQ/manageiq-providers-ansible_tower",
  "ManageIQ/manageiq-providers-azure",
  "ManageIQ/manageiq-providers-azure_stack",
  "ManageIQ/manageiq-providers-foreman",
  "ManageIQ/manageiq-providers-google",
  "ManageIQ/manageiq-providers-kubernetes",
  "ManageIQ/manageiq-providers-lenovo",
  "ManageIQ/manageiq-providers-nuage",
  "ManageIQ/manageiq-providers-openshift",
  "ManageIQ/manageiq-providers-openstack",
  "ManageIQ/manageiq-providers-ovirt",
  "ManageIQ/manageiq-providers-redfish",
  "ManageIQ/manageiq-providers-scvmm",
  "ManageIQ/manageiq-providers-vmware",
]

repo_names = ARGV[0].nil? ? ALL_REPO_NAMES : [ARGV[0]]

repo_names.each do |repo_name|
  stats = CodeClimate.repo_stats(repo_name)
  puts "Stats for repo #{repo_name}: #{stats.inspect}"
end
