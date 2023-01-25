#!/usr/bin/env ruby
require_relative "sprint_boundary_iterator"

last_day = ARGV[0] ? Date.parse(ARGV[0]) : Date.today
puts SprintBoundaryIterator.new(last_day).map { |num, range| "#{num}: #{range}" }
