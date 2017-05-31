require_relative 'sprint_statistics'
require 'active_support/core_ext/time/calculations'
require 'active_support/values/time_zone'

class Milestone
  def self.milestones
    @milestones ||= begin
      config = YAML.load_file('config.yaml')
      stats = SprintStatistics.new(ENV["GITHUB_API_TOKEN"])
      stats.client.milestones(config[:milestone_reference_repo], :state => "all")
    end
  end

  def self.sorted_milestones
    milestones.sort_by(&:created_at)
  end

  def self.day_after_milestone_change?(milestone)
    range(milestone.title).first + 1 == Date.today
  end

  def self.prompt_for_milestone(options = {})
    options.reverse_merge!(
      :default_index => 1,
      :count         => 3
    )

    display_milestones = sorted_milestones[options[:count] * -1..-1].reverse
    if day_after_milestone_change?(display_milestones.first)
      options[:default_index] += 1
    end

    print_milestones_prompt(display_milestones, options)

    index = prompt_user(options)
    display_milestones[index - 1]
  end

  def self.print_milestones_prompt(milestones, options)
    milestones.each_with_index { |m, idx| puts "#{idx + 1} : #{m.title}" }
    puts "#{options[:count] + 1} : Exit"
    print "\nChoose Milestone: [Default: #{options[:default_index]}] "
  end

  def self.prompt_user(options)
    answer = gets.chomp.to_i
    answer.zero? ? options[:default_index] : answer
  end

  def self.range(milestone_title)
    end_date = Date.parse(milestone_title)
    start_date = end_date - 2.weeks
    Range.new(start_date, end_date)
  end
end
