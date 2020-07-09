class OctokitClient
  attr_reader :handle

  def initialize(access_token)
    require 'octokit'
    Octokit.configure do |c|
      c.auto_paginate = true
      c.middleware = Faraday::RackBuilder.new do |builder|
        if ENV['DEBUG']
          builder.use(
            Class.new(Faraday::Response::Middleware) do
              def on_complete(env)
                api_calls_remaining = env.response_headers['x-ratelimit-remaining']
                STDOUT.puts "DEBUG: Executed #{env.method.to_s.upcase} #{env.url} ... api calls remaining #{api_calls_remaining}"
              end
            end
          )
        end

        builder.use Octokit::Response::RaiseError
        builder.use Octokit::Response::FeedParser
        builder.adapter Faraday.default_adapter
      end
    end

    @handle ||= Octokit::Client.new(:access_token => access_token)
  end
end
