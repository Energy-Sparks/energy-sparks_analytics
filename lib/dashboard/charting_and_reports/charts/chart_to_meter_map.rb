require 'singleton'

class ChartToMeterMap
  class UnknownChartMeterDefinition < StandardError; end

  include Singleton

  def backwards_compatible_series_data_manager_meter_map(school, chart_meter_definition)
    meter = meter(school, chart_meter_definition)

    return meter if meter.is_a?(Array)

    meter.heat_meter? ? [nil, meter] : [meter, nil]
  end

  def meter(school, chart_meter_definition)
    meter = vanilla_single_meter_map(school, chart_meter_definition)
    return meter unless meter == :not_mapped

    if chart_meter_definition == :all
      [school.aggregated_electricity_meters, school.aggregated_heat_meters]
    elsif mpxn?(chart_meter_definition)
      school.meter?(chart_meter_definition, true)
    else
      raise UnknownChartMeterDefinition, "Unknown chart meter definition type #{chart_meter_definition}"
    end
  end

  private

  def mpxn?(chart_meter_definition)
    chart_meter_definition.is_a?(String) || chart_meter_definition.is_a?(Integer)
  end

  def vanilla_single_meter_map(school, chart_meter_definition)
    case chart_meter_definition
    when :allheat;                                    school.aggregated_heat_meters
    when :allelectricity;                             school.aggregated_electricity_meters
    when :allelectricity_unmodified;                  school.aggregated_electricity_meters&.original_meter
    when :allelectricity_without_community_use;       school.aggregated_electricity_meter_without_community_usage
    when :allheat_without_community_use;              school.aggregated_heat_meters_without_community_usage
    when :storage_heaters_without_community_use;      school.storage_heater_meter_without_community_usage
    when :storage_heater_meter;                       school.storage_heater_meter
    when :solar_pv_meter, :solar_pv;                  school.aggregated_electricity_meters.sub_meters[:generation]
    when :unscaled_aggregate_target_electricity;      school.unscaled_target_meters[:electricity]
    when :unscaled_aggregate_target_gas;              school.unscaled_target_meters[:gas]
    when :unscaled_aggregate_target_storage_heater;   school.unscaled_target_meters[:storage_heater]
    when :synthetic_aggregate_target_electricity;     school.synthetic_target_meters[:electricity]
    when :synthetic_aggregate_target_gas;             school.synthetic_target_meters[:gas]
    when :synthetic_aggregate_target_storage_heater;  school.synthetic_target_meters[:storage_heater]
    else
      :not_mapped
    end
  end
end
