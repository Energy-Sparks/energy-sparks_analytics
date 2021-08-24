require 'require_all'
# creates a 'target' school from an existing school
# the initial implementation is the school with the
# and data shifted 1 year and then scaled by the target factor
# with an attempt to correct for holidays, but set on a per month basis or a nearby day basis
class TargetSchool < MeterCollection
  include Logging

  attr_reader :unscaled_target_meters

  def initialize(school, calculation_type)
    super(school.school,
          holidays:                 school.holidays,
          temperatures:             school.temperatures,
          solar_irradiation:        school.solar_irradiation,
          solar_pv:                 school.solar_pv,
          grid_carbon_intensity:    school.grid_carbon_intensity,
          pseudo_meter_attributes:  school.pseudo_meter_attributes_private)

    @original_school = school
    @unscaled_target_meters = {}

    @aggregated_heat_meters         = set_target(school.aggregated_heat_meters,         calculation_type)
    @aggregated_electricity_meters  = set_target(school.aggregated_electricity_meters,  calculation_type)
    @storage_heater_meter           = set_target(school.storage_heater_meter,           calculation_type)

    @name += ': target'
  end

  private

  def set_target(meter, calculation_type)
    target_set?(meter) ?  calculate_target(meter, calculation_type) : nil
  end

  def calculate_target(meter, calculation_type)
    meter = TargetMeter.calculation_factory(calculation_type, meter)
    @unscaled_target_meters[meter.fuel_type] = meter.non_scaled_target_meter
    meter
  end

  def target_set?(meter)
    !meter.nil? && meter.target_set?
  end
end

