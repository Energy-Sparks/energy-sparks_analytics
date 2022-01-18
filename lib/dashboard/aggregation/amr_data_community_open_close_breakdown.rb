class AMRDataCommunityOpenCloseBreakdown
  class NegativeClosedkWhCalculation < StandardError; end
  class InternalSelfTestAggregationError < StandardError; end

  def initialize(meter, open_close_times)
    @meter = meter # needs to be tied to meter so caching of results works
    @open_close_times = open_close_times
  end

  def days_kwh_x48(date, data_type)
    @days_kwh_x48 ||= {}
    @days_kwh_x48[date] ||= {}
    @days_kwh_x48[date][data_type] ||= calculate_days_kwh_x48(date, data_type)
  end

  def one_day_kwh(date, data_type)
    @one_day_kwh ||= {}
    @one_day_kwh[date] ||= {}
    @one_day_kwh[date][data_type] ||= days_kwh_x48(date, data_type).transform_values(&:sum)
  end

  def kwh(date, halfhour_index, data_type)
    days_kwh_x48(date, data_type).transform_values { |data_x48| data_x48[halfhour_index] }
  end

  def open_close_weights_x48(date)
    @open_close_weights_x48 ||= {}
    @open_close_weights_x48[date] ||= calculate_open_close_weights_x48(date)
  end

  def compact_print_weights(date)
    open_close_weights_x48(date).each do |type, weight_x48|
      puts "#{sprintf('%-15.15s',type.to_s)} #{weight_x48.map(&:to_i).join('')}"
    end
  end

  def series_names
    @open_close_times.series_names
  end

  private

  def calculate_open_close_weights_x48(date)
    usages = @open_close_times.usage(date)

    usages.transform_values do |opening_time|
      convert_times_to_weights_x48(opening_time)
    end
  end

  def convert_times_to_weights_x48(opening_times)
    @converted_times_x48 ||= {}
    @converted_times_x48[opening_times] ||= DateTimeHelper.weighted_x48_vector_multiple_ranges(opening_times)
  end

  # NB references to variables names kwh in this function could be to kwh, CO2 or £
  def calculate_days_kwh_x48(date, data_type)
    data_x48 = @meter.amr_data.days_kwh_x48(date, data_type)
    baseload_kw  = calc_baseload_kw(@meter, date, data_type)
    baseload_kwh = baseload_kw / 2.0

    type_of_remainder = @open_close_times.remainder_type(date)

    weights = open_close_weights_x48(date)

    kwh_breakdown = {}

    (0..47).each do |hhi|
      kwh = data_x48[hhi]
      hhi_weights = weights.transform_values { |data_x48| data_x48[hhi] }

      if hhi_weights.empty? # for speed
        set_hhi_value(kwh_breakdown, type_of_remainder, hhi, kwh)
      elsif hhi_weights.length == 1 && hhi_weights.key?(:schoolday_open) # for speed
        set_hhi_value(kwh_breakdown, :schoolday_open, hhi, kwh)
      else # slower more complex split half hour periods
        open_kwh, community_kwh, closed_kwh = split_half_hour_kwhs(hhi_weights, baseload_kwh, kwh)

        set_hhi_value(kwh_breakdown, :schoolday_open,   hhi, open_kwh)   unless open_kwh.zero?
        set_hhi_value(kwh_breakdown, type_of_remainder, hhi, closed_kwh) unless closed_kwh.zero?

        unless community_kwh.zero?
          community_weights = community_type_weights(hhi_weights)

          total_community_weight = total_community_weights(community_weights)

          community_weights.each do |type, weight|
            set_hhi_value(kwh_breakdown, type, hhi, community_kwh * weight / total_community_weight)
          end
        end
      end
    end

    check_totals(kwh_breakdown, date, data_type)

    kwh_breakdown
  rescue => e
    puts e.message
    puts e.backtrace
  end

  def check_totals(kwh_breakdown, date, data_type)
    # TODO(PH, 18Jan2022) remove if never thrown as has computation impact
    breakdown_total = kwh_breakdown.values.flatten.sum
    original_total   = @meter.amr_data.one_day_kwh(date, data_type)
    raise InternalSelfTestAggregationError, "breakdown = #{breakdown_total} #{data_type} original = #{original_total} for #{date}" unless similar?(breakdown_total, original_total)
  end

  def similar?(a, b)
    (a - b).magnitude < 0.0001
  end

  def community_type_weights(weights)
    weights.select { |type, _weight| type != :schoolday_open }
  end

  def total_community_weights(weights)
    community_type_weights(weights).values.sum
  end

  def set_hhi_value(community_kwh, type, hhi, kwh)
    community_kwh[type] ||= AMRData.one_day_zero_kwh_x48
    community_kwh[type][hhi] = kwh
  end

  # there is slight complexity when open/close times aren't specified on an exact
  # half hour boundary, the kwh/co2/£ values are calculated on a prorata basis
  # but if this period includes school closure then this needs to be calculated
  # and account for baseload assignment to community use
  def bucket_time_weights(weights)
    # divide half hour bucket up into 3 by time - open, closed, community
    school_open_time_in_half_hour = weights[:schoolday_open] || 0.0
    community_open_time_in_half_hour = [
      1.0 - school_open_time_in_half_hour, # time remaining in half hour when school not open
      community_type_weights(weights).values.max # longest of all community weights
    ].min
    school_closed_time_in_half_hour = [1.0 - school_open_time_in_half_hour - community_open_time_in_half_hour, 0.0].max
    [school_open_time_in_half_hour, community_open_time_in_half_hour, school_closed_time_in_half_hour]
  end
  
  # refer to charts in \Energy Sparks\Energy Sparks Project Team Documents\Analytics\Community use etc\
  def split_half_hour_kwhs(weights, baseload_kwh, kwh)
    open_t, community_t, closed_t = bucket_time_weights(weights)

    open_kwh      = kwh * open_t
    community_kwh = [(kwh - baseload_kwh) * community_t, 0.0].max
    closed_kwh    = kwh - open_kwh - community_kwh

    puts "Got here #{open_t}, #{community_t}, #{closed_t} #{baseload_kwh} #{kwh}" if closed_kwh < 0.0
    puts "And here #{open_kwh} #{community_kwh} #{closed_kwh} #{closed_kwh < 0.0}" if closed_kwh < 0.0

    raise NegativeClosedkWhCalculation, "Negative closed allocation #{closed_kwh}" if closed_kwh < 0.0

    [open_kwh, community_kwh, closed_kwh]
  end

  def calc_baseload_kw(meter, date, data_type)
    if meter.fuel_type == :electricity
      meter.amr_data.baseload_kw(date, meter.sheffield_simulated_solar_pv_panels?, data_type)
    else # gas and perhaps for storage heaters
      0.0
    end
  end
end
