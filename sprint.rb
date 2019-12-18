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
    print "\nChoose Milestone: [Default: #{default_index}] "

    answer = gets.chomp.to_i
    (answer.zero? ? default_index : answer) - 1
  end

  def self.recent_sprints(count)
    sprints(as_of: nil).slice_after { |s| s.date >= Date.today }.first.last(count)
  end

  def self.sprints(as_of: Date.today)
    require "active_support/core_ext/numeric/time"
    # The first date when we started doing this cadence
    number = 76
    date   = Date.parse("Jan 1, 2018")
    range  = Date.parse("Dec 12, 2018")..date

    as_of ||= date

    Enumerator.new do |y|
      loop do
        y << new(number, range) if date >= as_of

        last_date = date
        number += 1
        date += 2.weeks
        while (date.month == 12 && (22..31).cover?(date.day)) || (date.month == 1 && (1..4).cover?(date.day))
          date += 1.weeks
        end
        range = (last_date + 1.day)..date
      end
    end
  end

  attr_reader :number, :range

  def initialize(number, range)
    @number, @range = number, range
  end

  def date
    range.end
  end

  def title
    "Sprint #{number} Ending #{date.strftime("%b %-d, %Y")}"
  end
end
