# TODO (PH, 16Jan2022) remove reference to series_data_manager.rb once SeriesNames:: removed
# require_relative '../../lib/dashboard/charting_and_reports/charts/series_data_manager.rb'
# Centrica
class OpenCloseTimes
  class UnknownFrontEndType < StandardError; end
  attr_reader :open_times

  def initialize(attributes, holidays)
    @holidays = holidays
    oct = attributes[:open_close_times] || self.class.default_school_open_close_times_config
    @open_times = oct.map { |t| OpenCloseTime.new(t, holidays) }
  end

  def usage(date)
    @open_times.map do |usage_time|
      if usage_time.matched_usage?(date)
        [ usage_time.type, usage_time.time_ranges_for_week_day(date) ]
      else
        nil
      end
    end.compact.to_h
  end

  def print_usages(date)
    puts date.strftime('%a %d %b %Y')
    ap usage(date)
  end

  def self.convert_frontend_times(school_times, community_times, holidays)
    st = convert_frontend_time(school_times)
    ct = convert_frontend_time(community_times)
    OpenCloseTimes.new({ open_close_times: st + ct}, holidays)
  end

  def self.convert_frontend_time(times)
    times.map do |time_period|
      convert_front_end_time_period(time_period)
    end
  end

  def self.convert_front_end_time_period(time_period)
    {
      type:             convert_front_end_usage_type(time_period[:usage_type]),
      holiday_calendar: convert_front_end_calendar_type(time_period[:calendar_period]),
      time0:            {
        day_of_week: convert_front_end_day(time_period[:day]),
        from: time_period[:opening_time],
        to:   time_period[:closing_time]
      }
    }
  rescue => e
    puts e.message
    raise
  end

  def self.convert_front_end_usage_type(type)
    case type
    when :school_day
      :school_day_open
    when :community_use
      OpenCloseTime::COMMUNITY
    else
      raise UnknownFrontEndType, "Opening type #{type}"
    end
  end

  def self.convert_front_end_calendar_type(type)
    case type
    when :term_times
      :follows_school_calendar
    when :only_holidays
      :holidays_only
    when :all_year
      :no_holidays
    else
      raise UnknownFrontEndType, "Calendar period #{type}"
    end
  end

  def self.convert_front_end_day(type)
    raise UnknownFrontEndType, "Day type #{type}" unless OpenCloseTime.day_of_week_types.include?(type)
    type
  end

  def self.default_school_open_close_times_config
    [
      {
        type:             :school_day_open,
        holiday_calendar: :follows_school_calendar,
        time0:            { day_of_week: :weekdays, from: TimeOfDay.new(7, 0), to: TimeOfDay.new(16, 30) }
      }
    ]
  end

  def self.default_school_open_close_times(holidays)
    OpenCloseTimes.new({}, holidays)
  end

  def time_types
    [
      :school_day_open,
      OpenCloseTime.non_user_configurable_community_use_types.keys,
      @open_times.map { |config| config.type }
    ].flatten.uniq
  end

  def community_usage?
    @community_usage ||= !time_types.select { |tt| OpenCloseTime.community_usage_types.include?(tt) }.empty?
  end

  def series_names
    @series_names ||= time_types.sort_by { |type| OpenCloseTime.community_use_types[type][:sort_order] }
  end

  def remainder_type(date)
    case @holidays.day_type(date)
    when :holiday
      :holiday
    when :weekend
      :weekend
    when :schoolday
      :school_day_closed
    end
  end
end

class OpenCloseTime
  SCHOOL_OPEN   = :school_day_open
  SCHOOL_CLOSED = :school_day_closed
  HOLIDAY       = :holiday
  WEEKEND       = :weekend
  COMMUNITY     = :community

  def initialize(open_close_time, holidays)
    @open_close_time = open_close_time
    @holidays = holidays
  end

  def self.day_of_week_types
    %i[
      weekdays
      weekends
      everyday
      monday
      tuesday
      wednesday
      thursday
      friday
      saturday
      sunday
    ]
  end

  def self.calendar_types
    %i[
      follows_school_calendar
      no_holidays
      holidays_only
    ]
  end

  # e.g. flood lighting which might be electricity only
  def self.fuel_type_choices
    %i[
      both
      electricity_only
      gas_only
      none
    ]
  end

  def self.open_time_keys
    %i[time0 time1 time2 time3]
  end

  def self.user_configurable_community_use_types
    @@user_configurable_community_use_types ||= community_use_types.select { |_type, config| config[:user_configurable] != false }
  end

  def self.non_user_configurable_community_use_types
    @@non_user_configurable_community_use_types ||= community_use_types.select { |_type, config| config[:user_configurable] == false }
  end

  def self.community_use_types
    @@community_use_types ||= {
      SCHOOL_CLOSED =>    { user_configurable: false, sort_order: 1 },
      SCHOOL_OPEN   =>    {                           sort_order: 2},
      WEEKEND       =>    { user_configurable: false, sort_order: 3 },
      HOLIDAY       =>    { user_configurable: false, sort_order: 4 },
      COMMUNITY     =>    { community_use: true, sort_order:  5, benchmark_code: 'c' },
      dormitory:          { community_use: true, sort_order:  6, benchmark_code: 'd' },
      sports_centre:      { community_use: true, sort_order:  7, benchmark_code: 's' },
      swimming_pool:      { community_use: true, sort_order:  8, benchmark_code: 's' },
      kitchen:            { community_use: true, sort_order:  9, benchmark_code: 'k' },
      library:            { community_use: true, sort_order: 10, benchmark_code: 'l' },
      flood_lighting:     { community_use: true, sort_order: 11, benchmark_code: 'f', fuel_type: :electricity },
      other:              { community_use: true, sort_order: 12, benchmark_code: 'o' }
    }
  end

  def self.humanize_symbol(k)
    k.is_a?(Symbol) ? k.to_s.split('_').map(&:capitalize).join(' ') : k
  end

  def self.community_usage_types
    @@community_usage_types ||= community_use_types.select { |_type, config| config[:community_use] == true }.keys
  end

  def type
    @open_close_time[:type]
  end

  def matched_usage?(date)
    matches_start_end_date?(date) &&
    match_holiday?(date) &&
    match_weekday?(date)
  end

  # aka extract_times_for_week_day
  def time_ranges_for_week_day(date)
    matching_times = []

    open_close_times.each do |open_close_time|
      matching_times.push(open_close_time[:from]..open_close_time[:to]) if matches_weekday?(date, open_close_time)
    end

    matching_times
  end

  private

  def calendar_type
    @open_close_time[:holiday_calendar]
  end

  def match_holiday?(date)
    case calendar_type
    when :no_holidays # open 52 weeks of year
      true
    when :holidays_only
      @holidays.holiday?(date)
    when :follows_school_calendar
      !@holidays.holiday?(date)
    end
  end

  def match_weekday?(date)
    open_close_times.any?{ |open_close_time| matches_weekday?(date, open_close_time) }
  end

  def matches_weekday?(date, open_close_time)
    case open_close_time[:day_of_week]
    when :weekdays
      date.wday.between?(1, 5)
    when :weekends
      date.wday == 0 || date.wday == 6
    when :everyday
      true
    when :monday
      date.wday == 1
    when :tuesday
      date.wday == 2
    when :wednesday
      date.wday == 3
    when :thursday
      date.wday == 4
    when :friday
      date.wday == 5
    when :saturday
      date.wday == 6
    when :sunday
      date.wday == 0
    end
  end

  def matches_start_end_date?(date)
    (@open_close_time[:start_date] == nil || date >= @open_close_time[:start_date]) &&
    (@open_close_time[:end_date]   == nil || date <= @open_close_time[:end_date])
  end

  def open_close_times
    @open_close_time.select { |time_n, config| self.class.open_time_keys.include?(time_n) }.values
  end
end
