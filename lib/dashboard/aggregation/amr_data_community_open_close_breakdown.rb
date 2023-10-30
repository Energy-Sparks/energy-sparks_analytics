class AMRDataCommunityOpenCloseBreakdown
  class NegativeClosedkWhCalculation < StandardError; end
  class InternalSelfTestAggregationError < StandardError; end
  class UnknownCommunityUseParameter < StandardError; end

  def initialize(meter, open_close_times)
    @meter = meter
    @open_close_times = open_close_times
  end

  #unused, just documentation
  private_class_method def self.community_use_breakdown_example
    # example of community_use: parameter - see below
    # filter:    is a filter, just return community_only use, of school use only or both
    # aggregate: into all types of community use, aggregate the community use components,
    #            or just return a total single total
    # split_electricity_baseload: assign electricity baseload to separate
    #                             category or combine with community use
    # the returned values could be a single kwh/co2/£ value,
    # or a hash keyed by :school_day_open, closed etc. to kwh/co2/£ values
    # community_use: nil won't get this far as no breakdown and so handled within class AMRdata
    #
    # Aggregating community use into a single total:
    #
    # { filter: :community_only, aggregate: :all_to_single_value }
    {
      community_use: {
        filter:    :community_only || :school_only || :all,
        aggregate: :none || :community_use || :all_to_single_value,
        split_electricity_baseload: true || false
      }
    }
  end

  #Called from AMRData#days_kwh_x48
  def days_kwh_x48(date, data_type, community_use:)
    @days_kwh_x48 ||= {}
    @days_kwh_x48[date] ||= {}
    @days_kwh_x48[date][data_type] ||= calculate_days_kwh_x48(date, data_type)
    community_breakdown(@days_kwh_x48[date][data_type], community_use)
  end

  #Called from AMRData#one_day_kwh
  def one_day_kwh(date, data_type, community_use:)
    @one_day_kwh ||= {}
    @one_day_kwh[date] ||= {}
    @one_day_kwh[date][data_type] ||= days_kwh_x48(date, data_type, community_use: nil).transform_values(&:sum)
    community_breakdown(@one_day_kwh[date][data_type], community_use)
  end

  #Called from AMRData#kwh_date_range
  def kwh_date_range(start_date, end_date, data_type = :kwh, community_use:)
    sd = [@meter.amr_data.start_date, start_date].max
    ed = [@meter.amr_data.end_date, end_date].min
    return {} if sd > ed

    aggregate = {}
    (sd..ed).each do |date|
      breakdown = one_day_kwh(date, data_type, community_use: nil)
      breakdown.each do |breakdown_type, kwh_or_co2_or_£|
        aggregate[breakdown_type] ||= 0.0
        aggregate[breakdown_type] += kwh_or_co2_or_£
      end
    end

    community_breakdown(aggregate, community_use)
  end

  #Called from AMRData#kwh
  def kwh(date, halfhour_index, data_type, community_use:)
    community_use_copy = community_use.dup
    community_use_copy[:aggregate] = :none
    dkx = days_kwh_x48(date, data_type, community_use: community_use_copy)
    use_to_hh_kwh_co2_£ = dkx.transform_values { |data_x48| data_x48[halfhour_index] }
    community_breakdown(use_to_hh_kwh_co2_£, community_use)
  end

  #only called from test_community_use
  def compact_print_weights(date)
    open_close_weights_x48(date).each do |type, weight_x48|
      puts "#{sprintf('%-15.15s',type.to_s)} #{weight_x48.map(&:to_i).join('')}"
    end
  end

  #Called from DayType#calculate_day_type_names in series_data_manager
  def series_names(community_use)
    usage_types = @open_close_times.time_types.map { |t| [t, 0.0] }.to_h

    if community_use.nil?
      aggregate_data(usage_types, :community_use, false).keys
    else
      aggregate_data(usage_types, community_use[:aggregate], community_use[:split_electricity_baseload]).keys
    end
  end

  private

  def open_close_weights_x48(date)
    @open_close_weights_x48 ||= {}
    @open_close_weights_x48[date] ||= calculate_open_close_weights_x48(date)
  end

  #Produces a hash of period => array of weighted values
  #Will combine multiple ranges of same type into a single weighting
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

  # This is the basic method which does the breakdowns, called from +#days_kwh_x48+ and the
  # other public interface methods that calculate breakdowns delegate to that method.
  #
  # NB references to variables names kwh in this function could be to kwh, CO2 or £
  def calculate_days_kwh_x48(date, data_type)
    data_x48 = @meter.amr_data.days_kwh_x48(date, data_type)
    baseload_kw  = calc_baseload_kw(date, data_type)
    baseload_kwh = baseload_kw / 2.0

    #how will any unallocated usage be typed?
    type_of_remainder = @open_close_times.remainder_type(date)

    #Hash of periods => weighted vector
    weights = open_close_weights_x48(date)

    kwh_breakdown = {}

    (0..47).each do |hhi|
      kwh = data_x48[hhi]
      #new hash with single weighting for each type
      hhi_weights = weights.transform_values { |data_x48| data_x48[hhi] }

      if hhi_weights.empty? || hhi_weights.values.all?(&:zero?) # whole half hour nothing open
        set_hhi_value(kwh_breakdown, type_of_remainder, hhi, kwh)
      elsif hhi_weights[OpenCloseTime::SCHOOL_OPEN] == 1.0 # whole half hour school open
        set_hhi_value(kwh_breakdown, OpenCloseTime::SCHOOL_OPEN, hhi, kwh)
      else # slower more complex split half hour periods
        open_kwh, community_kwh, community_baseload_kwh, closed_kwh = split_half_hour_kwhs(hhi_weights, baseload_kwh, kwh)

        set_hhi_value(kwh_breakdown, OpenCloseTime::SCHOOL_OPEN,        hhi, open_kwh              ) unless open_kwh.zero?
        set_hhi_value(kwh_breakdown, OpenCloseTime::COMMUNITY_BASELOAD, hhi, community_baseload_kwh) unless community_baseload_kwh.zero?
        set_hhi_value(kwh_breakdown, type_of_remainder,                 hhi, closed_kwh            ) unless closed_kwh.zero?

        unless community_kwh.zero?
          community_weights = community_type_weights(hhi_weights)

          total_community_weight = total_community_weights(community_weights)

          community_weights.each do |type, weight|
            set_hhi_value(kwh_breakdown, type, hhi, community_kwh * weight / total_community_weight)
          end
        end
      end
    end

    kwh_breakdown
  end

  def community_type_weights(weights)
    weights.select { |type, _weight| type != :school_day_open }
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
    school_open_time_in_half_hour = weights[:school_day_open] || 0.0

    total_community_weights = community_type_weights(weights).values.max

    if total_community_weights.nil?
      [school_open_time_in_half_hour, 0.0, 1 - school_open_time_in_half_hour]
    else
      community_open_time_in_half_hour = [
        1.0 - school_open_time_in_half_hour, # time remaining in half hour when school not open
        community_type_weights(weights).values.max # longest of all community weights
      ].compact.min
      school_closed_time_in_half_hour = [1.0 - school_open_time_in_half_hour - community_open_time_in_half_hour, 0.0].max
      [school_open_time_in_half_hour, community_open_time_in_half_hour, school_closed_time_in_half_hour]
    end
  end

  # refer to charts in \Energy Sparks\Energy Sparks Project Team Documents\Analytics\Community use etc\
  def split_half_hour_kwhs(weights, baseload_kwh, kwh)
    open_t, community_t, _closed_t = bucket_time_weights(weights)

    open_kwh                = kwh * open_t
    community_kwh           = [(kwh - baseload_kwh) * community_t, 0.0].max
    community_baseload_kwh  = [baseload_kwh * community_t, kwh].min
    #LD 2023-3-21 dont allocate community baseload if community use has been clipped to zero
    community_baseload_kwh  = 0.0 if community_kwh == 0.0

    closed_kwh              = kwh - open_kwh - community_kwh - community_baseload_kwh
    closed_kwh              = 0.0 if closed_kwh.magnitude < 0.00000001 # remove floating point noise

    # TODO(PH, 4Apr2022) there seems to be a problem with some Orsis solar schools providing small -tbe mains consumption
    #                    hence kwh > 0.0 additjon below, needs further investigation of root cause
    raise NegativeClosedkWhCalculation, "Negative closed allocation #{closed_kwh} Before #{kwh} => Open #{open_kwh} + Closed #{closed_kwh} + Comms baseload #{community_baseload_kwh} + Comms #{community_kwh} (Comms time #{community_t})" if closed_kwh < 0.0 && kwh > 0.0

    [open_kwh, community_kwh, community_baseload_kwh, closed_kwh]
  end

  def calc_baseload_kw(date, data_type)
    if @meter.fuel_type == :electricity
      @meter.amr_data.baseload_kw(date, @meter.sheffield_simulated_solar_pv_panels?, data_type)
    else # gas and perhaps for storage heaters
      0.0
    end
  end

  #This is called before the other methods return, to create the breakdown
  def community_breakdown(data, community_use)
    community_use ||= { aggregate: :none, filter: :all}

    filtered_data = filter_community_use(data, community_use[:filter])
    aggregate_data(filtered_data, community_use[:aggregate], community_use[:split_electricity_baseload])
  end

  def filter_community_use(data, community_use_use, split_electricity_baseload = false)
    case community_use_use
    when :community_only
      data.select do |usage_type, _kwh_or_£_co2_x_scalar_or_x48|
        OpenCloseTime.community_usage_types.include?(usage_type) &&
          !include_electricity_baseload?(usage_type,  split_electricity_baseload)
      end
    when :school_only
      data.reject { |usage_type, _kwh_or_£_co2_x_scalar_or_x48| OpenCloseTime.community_usage_types.include?(usage_type) }
    when :all
      data
    else
      raise UnknownCommunityUseParameter, "filter parameter #{community_use_use} unknown"
    end
  end

  def include_electricity_baseload?(usage_type,  split_electricity_baseload)
    usage_type == OpenCloseTime::COMMUNITY_BASELOAD && split_electricity_baseload
  end

  def aggregate_data(data, breakdown, split_electricity_baseload)
    case breakdown
    when :none
      data
    when :community_use
      use           = filter_community_use(data, :school_only)
      community_use = filter_community_use(data, :community_only, split_electricity_baseload)
      if @open_close_times.community_usage?
        if split_electricity_baseload
          use[OpenCloseTime::COMMUNITY]          = aggregate_values(community_use.values)
          use[OpenCloseTime::COMMUNITY_BASELOAD] = data[OpenCloseTime::COMMUNITY_BASELOAD] || 0.0
        else
          use[OpenCloseTime::COMMUNITY]          = aggregate_values(community_use.values)
        end
      end
      use
    when :all_to_single_value
      # return summed values, no hash/key indexing
      aggregate_values(data.values)
    else
      raise UnknownCommunityUseParameter, "aggregation parameter #{breakdown} unknown"
    end
  end

  def aggregate_values(data)
    if data.first.is_a?(Array)
      AMRData.fast_add_multiple_x48_x_x48(data)
    else
      data.sum(0.0) # 0.0 because [].sum => Integer
    end
  end
end
