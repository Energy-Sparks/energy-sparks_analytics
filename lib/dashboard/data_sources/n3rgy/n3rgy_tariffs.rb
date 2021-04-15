class N3rgyTariffs
  class UnexpectedState < StandardError; end
  class UnexpectedRateType < StandardError; end
  # can't use Date::Ininity as only comparable on rhs of comparison
  # see this longstanding bug report: https://bugs.ruby-lang.org/issues/6753
  INFINITE_DATE = Date.new(2050, 1, 1)
  def initialize(tariff_data)
    @tariff_data = tariff_data
  end

  # compresses standing charges, and rates (1 row per half hour)
  # into meter attribute like descriptive tariffs
  # approx 16,000 to 2 compression
  def parameterise
    return nil unless tariffs_available?
    {
      kwh_rates:        process_kwh_rates(       @tariff_data[:kwh_tariffs]),
      standing_charges: process_standing_charges(@tariff_data[:standing_charges])
    }
  end

  def tariffs_available?
    !@tariff_data.nil? && !@tariff_data[:kwh_tariffs].empty? && !@tariff_data[:standing_charges].empty?
  end

  private

  def process_kwh_rates(rates)
    daily_tariffs = parameterise_all_days(rates)
    grouped_data = group_tariffs_by_date(daily_tariffs)
    grouped_data = WeekdayRate.new.group_by_weekday(grouped_data) if WeekdayRate.weekday_tariff?(grouped_data)
    grouped_data
  end

  def parameterise_all_days(rates)
    rates.map do |date, days_rates|
      [
        date,
        parameterise_day_rates(days_rates)
      ]
    end
  end

  # compact { date1 => { rates1 },......daten => { ratesn } }
  # to {date1..datex => rates1, ..... datex+1..daten => ratesn }
  def group_tariffs_by_date(daily_tariffs)
    grouped_rates = daily_tariffs.to_a.slice_when { |prev, curr| !self.class.compare_two_rates(curr[1], prev[1])}.to_a
    grouped_rates.map do |group|
      [group.first[0]..group.last[0], group.first[1]]
    end.to_h
  end

  def self.compare_two_rates(rates1, rates2)
    # rates1 == rates2 object comparison doesn't work, think
    # because the range comparison operator isn't working for TimeOfDay30mins or Date
    # it doesn't seem to call TimeOfDay30mins.== or TimeOfDay30mins.<=>
    # suspect must do an object address comparison instead?
    rates1.keys == rates2.keys && rates1.values == rates2.values
  end

  # compress rates = [48 values] into hash of 'time of day range' to rate
  def parameterise_day_rates(days_rates)
    indexed_rates = days_rates.map.with_index { |dr, hh_i| [hh_i, dr] }
    grouped_rates = indexed_rates.to_a.slice_when { |prev, curr| curr[1] != prev[1]}.to_a
    indexed_group_rates = grouped_rates.map do |group|
      [group.first[0]..group.last[0], group.first[1]]
    end.to_h
    indexed_group_rates.transform_keys!   { |hh_i_range| hh_index_to_range(hh_i_range) }
    indexed_group_rates.transform_values! do |rate|
      if rate.is_a?(Float)
        round_rate(rate)
      elsif rate.is_a?(Hash) && rate[:type] == :tiered
        convert_tiered_tariff(rate)
      else
        raise UnexpectedRateType, rate.nil?  ? 'Unexpected Nil rate type' : "Unexpected type #{rate.class.name}"
      end
    end
  end

  def convert_tiered_tariff(tariff)
    tariff[:tariffs].map do |index, rate|
      start_threshold = index == 1 ? 0.0 : tariff[:thresholds][index - 1].to_f
      end_threshold = tariff[:thresholds].key?(index) ? tariff[:thresholds][index].to_f : Float::INFINITY
      [
        start_threshold..end_threshold,
        round_rate(rate)
      ]
    end.to_h
  end

  def round_rate(rate)
    (rate * 1000000.0).round(0)/1000000.0
  end

  def hh_index_to_range(hh_i_range)
    start_tod = TimeOfDay30mins.time_of_day_from_halfhour_index(hh_i_range.first)
    end_tod   = TimeOfDay30mins.time_of_day_from_halfhour_index(hh_i_range.last)
    start_tod..end_tod
  end

  # compress { date1 -> rate1, .....daten => rate1, datem => raten, dateo => raten}
  # into {date1..daten => rate1, ....... datem..dateo => raten }
  def process_standing_charges(standing_charges)
    grouped_rates = standing_charges.to_a.slice_when { |prev, curr| curr[1] != prev[1]}.to_a
    compressed_date_rates = grouped_rates.map do |group|
      [group.first[0], group.first[1]]
    end.to_h
    end_dates = compressed_date_rates.keys[1..10000].map{ |d| d - 1}
    end_dates.push(INFINITE_DATE)
    date_ranged_rates = compressed_date_rates.transform_keys.with_index do |date, index|
      date..end_dates[index]
    end
  end

  # analyses tariffs where there are different tariffs on different days of
  # the week. Groups similar tariffs on same days of the week in order
  # to come up with a summary from the raw per kwh rate data
  # TODO(PH, 12Mar2021): may end up with an artifact day at the start of end which
  #                      doesn'tcomprise a set of weekdays matching the other weekday groups
  class WeekdayRate
    def initialize
      @debug = false
    end

    def self.weekday_tariff?(grouped_data)
      stats = Hash.new(0)
      grouped_data.each do |date_range, rates|
        stats[date_range_days(date_range)] += 1
      end
      stats.values.sum > 14
    end

    def group_by_weekday(grouped_data)
      weekday_groups = group_weekdays_where_identical_rate_within_a_week(grouped_data)

      tariffs = weekday_groups.map do |weekdays, date_ranges_to_rates|
        log('Processing =============== weekdays: ', weekdays)
        same_rate_groups   = group_where_same_rates(date_ranges_to_rates)
        contiguous_groups = split_group_where_not_7_days_apart(same_rate_groups)
        convert_to_tariff(contiguous_groups, weekdays)
      end.flatten
      log('Finals Resulting tariffs', tariffs)
      tariffs
    end

    private

    def log(message, data)
      if @debug
        puts "#{caller_locations(1,1)[0].label}: #{message}:"
        ap data, { limit: 4 }
      end
    end

    def group_weekdays_where_identical_rate_within_a_week(grouped_data)
      log('in', grouped_data)
      weekday_groups = readings = Hash.new { |h, k| h[k] = Array.new }
      grouped_data.each do |date_range, rates|
        if self.class.date_range_days(date_range) <= 7
          weekdays = date_range.to_a.map(&:wday)
          weekday_groups[weekdays].push({date_range => rates})
        else
          # probably should just push back onto the list
          raise UnexpectedState, 'unexpected problem'
        end
      end
      log('out', weekday_groups)
      weekday_groups
    end

    def group_where_same_rates(date_ranges_to_rates)
      log('in', date_ranges_to_rates)
      grouped_rates = date_ranges_to_rates.slice_when  do |prev, curr|
        !N3rgyTariffs.compare_two_rates(curr.values[0], prev.values[0])
      end.to_a
      log('out', grouped_rates)
      grouped_rates
    end

    def split_group_where_not_7_days_apart(grouped_rates)
      log('in', grouped_rates)
      matched_group = []
      grouped_rates.each do |one_group|
        split_grouped_rates = one_group.slice_when do |prev, curr|
          (curr.keys[0].first - prev.keys[0].first) != 7 # 7 days apart
        end.to_a
        matched_group.push(split_grouped_rates)
      end
      log('out', grouped_rates.flatten(1))
      matched_group.flatten(1)
    end

    def convert_to_tariff(matched_group, weekdays)
      log('in', matched_group)
      log('in', weekdays)
      tariff = matched_group.map do |single_rate_group|
        start_date = single_rate_group.first.keys.first.first
        end_date   = single_rate_group.last.keys.last.last
        {
          # insert which seekdays this tariff is associated with
          start_date..end_date => single_rate_group.first.values.first.merge({ weekdays: weekdays })
        }
      end
      log('out', tariff)
      tariff
    end

    def self.date_range_days(date_range)
      (date_range.last - date_range.first + 1).to_i
    end
  end
end
