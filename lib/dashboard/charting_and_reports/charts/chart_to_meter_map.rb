# frozen_string_literal: true

require 'singleton'

class ChartToMeterMap
  class UnknownChartMeterDefinition < StandardError; end

  include Singleton

  def meter(school, chart_meter_definition)
    meter = logical_meter_names(school, chart_meter_definition)
    return meter unless meter == :not_mapped

    if chart_meter_definition == :all
      # TODO: not storage heaters?
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

  # rubocop:disable Metrics/CyclomaticComplexity
  def logical_meter_names(school, chart_meter_definition)
    case chart_meter_definition
    when :allheat then                                    school.aggregated_heat_meters
    when :allelectricity then                             school.aggregated_electricity_meters
    when :allelectricity_unmodified then                  school.aggregated_electricity_meters&.original_meter
    when :allelectricity_without_community_use then       school.aggregated_electricity_meter_without_community_usage
    when :allheat_without_community_use then              school.aggregated_heat_meters_without_community_usage
    when :storage_heaters_without_community_use then      school.storage_heater_meter_without_community_usage
    when :storage_heater_meter then                       school.storage_heater_meter
    when :solar_pv_meter, :solar_pv then                  school.aggregated_electricity_meters.sub_meters[:generation]
    when :unscaled_aggregate_target_electricity then      school.unscaled_target_meters[:electricity]
    when :unscaled_aggregate_target_gas then              school.unscaled_target_meters[:gas]
    when :unscaled_aggregate_target_storage_heater then   school.unscaled_target_meters[:storage_heater]
    when :synthetic_aggregate_target_electricity then     school.synthetic_target_meters[:electricity]
    when :synthetic_aggregate_target_gas then             school.synthetic_target_meters[:gas]
    when :synthetic_aggregate_target_storage_heater then  school.synthetic_target_meters[:storage_heater]
    else
      :not_mapped
    end
  end
  # rubocop:enable Metrics/CyclomaticComplexity
end
