require_relative 'sprint_boundary_iterator'
class Sprint
  def self.prompt_for_sprint(count)
    sprints = recent_sprints(count).reverse
    default_index = Date.today == sprints.first.range.begin ? 1 : 0
    sprints[prompt_user(sprints, default_index)]
  end

  private_class_method def self.prompt_user(sprints, default_index)
    default_index += 1

    sprints.each_with_index { |s, i| puts "#{i + 1} : #{s.title}" }
    puts "#{sprints.size + 1} : Exit"
    print "\nChoose Sprint: [Default: #{default_index}] "

    answer = gets.chomp.to_i
    (answer.zero? ? default_index : answer) - 1
  end

  def self.recent_sprints(count)
    sprints(as_of: nil).slice_after { |s| s.date >= Date.today }.first.last(count)
  end

  def self.sprints(as_of: Date.today)
    as_of ||= SprintBoundaryIterator.start_range.end

    SprintBoundaryIterator.new.collect do |number, range|
      new(number, range) if range.end >= as_of
    end
  end

  attr_reader :number, :range

  def initialize(number, range)
    @number, @range = number, range
  end

  def before_range?(timestamp)
    timestamp.to_date < range.begin
  end

  def after_range?(timestamp)
    timestamp.to_date > range.end
  end

  def in_range?(timestamp)
    return false if timestamp.nil?
    range.include?(timestamp.to_date)
  end

  def date
    range.end
  end

  def title
    "Sprint #{number} Ending #{date.strftime("%b %-d, %Y")}"
  end
end
