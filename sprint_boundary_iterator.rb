class SprintBoundaryIterator
  include Enumerable
  require "active_support/core_ext/numeric/time"
  require 'pathname'
  require 'yaml'

  def initialize
    old_boundaries_yaml = Pathname.new(__dir__).join("old_sprint_boundaries.yml")
    @old_boundaries = File.exist?(old_boundaries_yaml) ? YAML.load_file(old_boundaries_yaml) : []
  end

  def each
    number, range = next_boundary
    today = Date.today
    while today > range.first do
      yield number, range

      number, range = next_boundary
    end
  end

  private

  # The first sprint when we started doing the cadence that compute_next_range works with properly
  FIRST_AUTOCOMPUTED_NUMBER = 76
  FIRST_AUTOCOMPUTED_RANGE  = Date.parse("Dec 12, 2017")..Date.parse("Jan 1, 2018")

  def next_boundary
    if @old_boundaries.any?
      @last_number, start_date, end_date = @old_boundaries.shift
      @last_range = start_date..end_date
    elsif @last_number.nil?
      @last_number = FIRST_AUTOCOMPUTED_NUMBER
      @last_range  = FIRST_AUTOCOMPUTED_RANGE
    else
      @last_range   = compute_next_range(@last_range)
      @last_number += 1
    end

    [@last_number, @last_range]
  end

  def compute_next_range(current)
    date = current.end + 2.weeks
    while (date.month == 12 && (22..31).cover?(date.day)) || (date.month == 1 && (1..4).cover?(date.day))
      date += 1.weeks
    end
    current = (current.end + 1.day)..date
  end
end
