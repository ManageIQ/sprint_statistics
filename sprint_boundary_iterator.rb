class SprintBoundaryIterator
  include Enumerable
  require "active_support/core_ext/numeric/time"

  def self.start
    # The first date when we started doing this cadence
    [76, Date.parse("Dec 12, 2017")..Date.parse("Jan 1, 2018")]
  end

  def self.start_range
    start.last
  end

  def self.start_number
    start.first
  end

  def each
    number, range = self.class.start
    today = Date.today
    while today > range.first do
      yield number, range

      range = next_range(range)
      number   += 1
    end
  end

  private

  def next_range(current)
    date = current.end + 2.weeks
    while (date.month == 12 && (22..31).cover?(date.day)) || (date.month == 1 && (1..4).cover?(date.day))
      date += 1.weeks
    end
    current = (current.end + 1.day)..date
  end
end
