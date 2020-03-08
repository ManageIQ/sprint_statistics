class DateRange
  DATE_SELECTION_COUNT = 7

  attr_reader :start_date, :end_date

  def initialize(start_date, end_date)
    @start_date = start_date
    @end_date = end_date

    # Bump end_date to the end of the day to cover the full day
    full_end_day = @end_date + 1
    @range = Range.new(@start_date.to_time.to_i, full_end_day.to_time.to_i)
  end

  def to_s
    "#{@start_date}..#{@end_date}"
  end

  def include?(date)
    @range.include?(date.to_time.to_i)
  end

  def self.prompt_for_range(config)
    options = config.reverse_merge(
      :number_of_days_selection => DATE_SELECTION_COUNT,
      :sprint_length_in_weeks => 2,
      :sprint_end_day => 'monday'
    )

    print_ranges(options)
    end_date = prompt_user(options)

    print "\nSprint Length (in weeks) [Default: #{options[:sprint_length_in_weeks]}] "
    sprint_length = prompt_user(:default_value => options[:sprint_length_in_weeks])

    self.new(*generate_range(end_date, sprint_length))
  end

  def self.print_ranges(options)
    today = Date.today

    puts "Select the sprint END DATE (Ctrl-C to exit):"
    1.upto(options[:number_of_days_selection]).each do |offset|
      d = today - (offset - 1)

      # sprint_end_day = Day of the week: monday, tuesday, etc.
      is_default = d.send("#{options[:sprint_end_day].downcase}?")
      options[:default_value] = offset if is_default

      puts "  [#{offset}] : #{d.iso8601} (#{d.strftime("%A")}#{is_default ? " **" : ""})"
    end

    options[:default_value] = 1 if options[:default_value].blank?
    print "\nChoose an option or enter date [YYYY-MM-DD] [Default: #{options[:default_value]}] "
  end

  def self.prompt_user(options)
    answer = gets.chomp
    answer.to_i.zero? ? options[:default_value] : answer
  end

  def self.generate_range(index_or_date, sprint_length)
    date = index_or_date.to_i < 2013 ? (Date.today - (index_or_date.to_i - 1)) : Date.parse(index_or_date)

    sprint_length_days = sprint_length.to_i * 7
    return (date - sprint_length_days), date
  end
end
