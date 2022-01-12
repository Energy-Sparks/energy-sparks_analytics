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

  def disaggregate
    disaggregate_by_fuel_type(:electricity)
    disaggregate_by_fuel_type(:gas)
  end

  def disaggregate_by_fuel_type(fuel_type)
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

  private

  def disaggregate_partial_meters(fuel_type)
    puts "disaggregate_partial_meters not implemented"
  end

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
end
