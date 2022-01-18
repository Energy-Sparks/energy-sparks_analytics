# Centrica
class DisaggregateCommunityUsage
  include Logging
  include AggregationMixin

  attr_reader :meter_collection # to keep mixin happy, not ideal

  def initialize(school)
    @school = @meter_collection = school
  end

  def can_disaggregate?(fuel_type)
    # check community use opening and closing times
    # against normal school open/close times if overlap
    # then return false
    true
  end

  def self.test_dates
    @@test_dates ||= [
      (Date.new(2022, 1, 1)..Date.new(2022, 1, 14)).to_a,
      (Date.new(2021, 1, 7)..Date.new(2021, 1, 14)).to_a,
    ].flatten
  end

  def disaggregate
    disaggregate_by_fuel_type(:electricity)
    disaggregate_by_fuel_type(:gas)
  end

  def disaggregate_by_fuel_type(fuel_type)
    puts "Disaggregating for community use"
    # there are 2 types of disaggregation
    # whole meter   - the meter aggregation is similar to the normal but
    #               - the fewer meters are aggregated than normal
    #               - and assigned to school.aggregated_electricity_meter_without_community_usage
    #               -              or school.aggregated_heat_meters_without_community_usage
    # partial_meter - where a single meter is split up in the same way as storage heaters
    #               - and for electricity a section above baseload is removed and reassigned
    #               - and for gas the whole lot is removed
    #               - there may be specific implementations e.g. for flood lighting
    # if a mix of representations occured over time
    # then its likely all processing will be down the partial_meter route

    RecordTestTimes.instance.record_time(@school.name, 'community disaggregation', 'partial'){
      disaggregate_partial_meters(fuel_type)
    }
    RecordTestTimes.instance.record_time(@school.name, 'community disaggregation', 'whole'){
      disaggregate_whole_meters(fuel_type)
    }
  end

  def community_weight(date, meter)
    @community_weight ||= {}
    @community_weight[date] ||= calculate_community_weight(date, meter)
  end

  def community_usage_types(meter)
    oc = SchoolOpenCloseTimes.new(@school, SchoolOpenCloseTimes.example_open_close_times, meter)
    oc.school_usages_types(meter)
  end

  def community_weights_half_hour(date, halfhour_index, meter)
    oc = SchoolOpenCloseTimes.new(@school, SchoolOpenCloseTimes.example_open_close_times, meter)

    @one_days_disaggregation ||= {}
    @one_days_disaggregation[date] ||= oc.one_day_disaggregation(meter, date)
    meter.amr_data.days_amr_data(date).set_community_open_close_usage_x48(@one_days_disaggregation[date])
    @one_days_disaggregation[date]
  end

  def community_weights(date, meter)
    oc = SchoolOpenCloseTimes.new(@school, SchoolOpenCloseTimes.example_open_close_times, meter)
    
    @one_days_community_aggregates ||= {}
    @one_days_community_aggregates[date] ||= oc.one_day_disaggregation(meter, date).transform_values(&:sum)
    meter.amr_data.days_amr_data(date).set_community_open_close_usage_x48(@one_days_community_aggregates[date])
    @one_days_community_aggregates[date]
  end

  private

  def disaggregate_whole_meters(fuel_type)
    meters = @school.underlying_meters(fuel_type)

    community_use_meters     = meters.select { |m| m.has_exclusive_community_use? }
    non_community_use_meters = meters.reject { |m| m.has_exclusive_community_use? }

    aggregate_meter_to_copy = @school.aggregate_meter(fuel_type)

    meter_name = "#{aggregate_meter_to_copy.mpxn}-non-community-use-#{fuel_type}"

    aggregate_non_community_use_meter = create_aggregate_meter(
      aggregate_meter_to_copy, non_community_use_meters, fuel_type, meter_name, meter_name, meter_name
    )

    @school.set_aggregate_meter_non_community_use_meter(fuel_type, aggregate_non_community_use_meter)
  end

  def disaggregate_partial_meters(fuel_type)
    puts "disaggregate_partial_meters not implemented"

    meters = @school.underlying_meters(fuel_type)

    meters.each do |meter|
      disaggregate_meter_for_community_use(meter)
    end
  end

  def disaggregate_meter_for_community_use(meter)

    return

    amr_data = meter.amr_data
    oc = SchoolOpenCloseTimes.new(@school, SchoolOpenCloseTimes.example_open_close_times, meter)
    weights = {}

    (amr_data.start_date..amr_data.end_date).each do |date|
      # day_kwh_x48 = amr_data.days_kwh_x48(date, type = :kwh)
      weights[date] = oc.open_close_weights_x48(date)
    end

    puts self.class.test_dates.map { |d| d.strftime('%a %d %b %Y') }

    @community_weights = oc.merge_down_community_weights(weights)

    self.class.test_dates.each do |date|
      ap community_weight(date, nil)
    end
  end

  def calculate_community_weight(date, meter)
    oc = SchoolOpenCloseTimes.new(@school, SchoolOpenCloseTimes.example_open_close_times, meter)
    w = oc.open_close_weights_x48(date)
    oc.aggregate_weights(w)
  end
end
