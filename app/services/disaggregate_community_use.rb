# Centrica
class DisaggregateCommunityUsage
  def initialize(school)
  end
  def can_disaggregate?(fuel_type)
    # check community use opening and closing times
    # against normal school open/close times if overlap
    # then return false
    true
  end

  def disaggregate
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
  end
end
