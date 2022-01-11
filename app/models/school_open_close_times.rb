# Centrica
class SchoolOpenCloseTimes
  class TooManyMatchingOpeningTimes < StandardError; end

  def initialize(school, open_close_times, meter)
    @school = school
    @open_close_times = open_close_times
    @meter = meter
  end

  def self.community_use_types
    %i[
      school
      flood_lighting
      community
      swimming_pool
      dormitory
      kitchen
      sports_centre
      library
      other
    ]
  end

  def self.example_open_close_times(school)
    [ # maps onto meter attribute hash?
      {
        type:               :school,  # this is the default for non community use
        holiday_calendar:   school.holidays,
        open_times:         { 1..5 => [ TimeOfDay.new(8, 30)..TimeOfDay.new(13, 30) ] }
      },
      {
        type:               :flood_lighting,
        holiday_calendar:   school.holidays,
        end_date:           Date.new(2025, 1, 1),
        fixed_power_kw:     25.0, # || :automatic_analysis
        # should be disaggreable as outside school hours
        open_times:         { 0..7 => [ TimeOfDay.new(18, 0)..TimeOfDay.new(20, 0) ]}
      },
      {
        type:               :community,
        start_date:         Date.new(2018, 9, 1),
        end_date:           Date.new(2020, 8, 31),
        holiday_calendar:   :follows_school_calendar,
        # should be disaggreable as outside school hours
        open_times: {
                      1..5 => [ TimeOfDay.new(18, 0)..TimeOfDay.new(20, 0) ],
                      # single weekdays ratherv than range may not be allowed by mater attribute framework?
                      0    => [ TimeOfDay.new(10, 0)..TimeOfDay.new(16, 0) ],
                      6    => [ TimeOfDay.new(10, 0)..TimeOfDay.new(18, 0) ]
                    }
      },
      {
        type:               :community,
        start_date:         Date.new(2020, 9, 1),
        holiday_calendar:   nil,
        # should be disaggreable as outside school hours
        open_times: { 1..5 => [ TimeOfDay.new(18, 0)..TimeOfDay.new(20, 0) ] },
      },
      {
        type:               :swimming_pool,
        holiday_calendar:   nil,
        # should be disaggreable as outside school hours
        open_times: {
                      0..7 => [ TimeOfDay.new(6, 0)..TimeOfDay.new(8, 0),
                                TimeOfDay.new(18, 0)..TimeOfDay.new(20, 0) ]
                    }
      },
      # { type: community } - defines a whole meter being for community use etc.
    ]
  end

  # returns hash of usage_type => [0.0 to 1.0, ......] x 48 weights
  # currently an open/close time on a non-half hour boundary will
  # proportionally split the weight within the half hour bucket
  def open_close_weights_x48(date)
    check_times_valid(true)

    half_hourly_vectors = {}

    open_close_times.each do |times|
      community_times_for_date = times.select { |t| times_match_date?(single_time, date) }

      community_times_for_date.map do |single_time|
        weights_x48 = convert_times_to_weights_x48(date, single_time[:open_times])

        if weights_x48.nil?
          nil
        else
          [
            single_time[:type],
            convert_times_to_weights_x48(date, single_time[:open_times])
          ]
        end
      end.compact.to_h
    end
  end

  def disaggreable?
    return true || false || :partially
  end

  def times_match_date?(single_time, date)
    (single_time[:start_date] == nil || single_time[:start_date] >= date) &&
    (single_time[:end_date]   == nil || single_time[:end_date]   <= date)
  end

  def check_times_valid(raise_exception = false)
    # TODO - check for overlaps in similar times
    return true
  end

  def convert_times_to_weights_x48(date, opening_times)
    matched_opening_times = opening_times.keys.select { |dow_range| date.wday == dow_range || date.wday.between?(dow_range.first, dow_range.last) }
    return nil if opening_times.empty?

    raise TooManyMatchingOpeningTimes, "Too many opening times for #{date}" if opening_times.length > 1

    DateTimeHelper.weighted_x48_vector_multiple_ranges(matched_opening_times.first)
  end
end
