require "active_support"
require "active_support/core_ext/numeric/time"
require "pathname"
require "yaml"

class SprintBoundaryIterator
  include Enumerable

  def self.[](sprint_number)
    new(nil)[sprint_number]
  end

  def initialize(last_day = Date.today)
    @last_day = last_day

    exceptions_yml = Pathname.new(__dir__).join("sprint_boundary_exceptions.yml")
    @exceptions = exceptions_yml.exist? ? YAML.unsafe_load(exceptions_yml.read) : {}
    @exceptions.transform_values! { |range_start, range_end| (range_start..range_end) }
  end

  def each
    init_iterator

    loop do
      number, range = next_boundary
      yield number, range
      break if @last_day && range.end >= @last_day
    end
  end

  def [](sprint_number)
    detect { |number, _range| number == sprint_number.to_i }.last
  end

  def self.start_range
    new.first.last
  end

  private

  INITIAL_SPRINT = 8

  def init_iterator
    @last_number = INITIAL_SPRINT - 1
    @last_range  = nil
  end

  def next_boundary
    next_number = @last_number + 1
    next_range  = @exceptions[next_number] || compute_next_range(@last_range, sprint_length(next_number))

    @last_number, @last_range = next_number, next_range
  end

  def compute_next_range(current, sprint_length)
    date = current.end + sprint_length
    date += 1.weeks while winter_break?(date) || july_4_break?(date)
    (current.end + 1.day)..date
  end

  # With sprint 52 (first sprint of 2017) we switched to 2 week sprints
  def sprint_length(number)
    number >= 52 ? 2.weeks : 3.weeks
  end

  def winter_break?(date)
    (date.month == 12 && (21..31).cover?(date.day)) || (date.month == 1 && (1..3).cover?(date.day))
  end

  def july_4_break?(date)
    date.month == 7 && (3..4).cover?(date.day)
  end
end
