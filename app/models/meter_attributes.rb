require_relative './meter_attribute_types'
class MeterAttributes

  class AutoInsertMissingReadings < MeterAttributeTypes::AttributeBase

    id :meter_corrections_auto_insert_missing_readings
    key :auto_insert_missing_readings
    aggregate_over :meter_corrections
    description 'Meter correction > Auto insert missing readings'

    structure MeterAttributeTypes::Hash.define(
      structure: {
        type: MeterAttributeTypes::Symbol.define(allowed_values: [:weekends])
      }
    )
  end

  class NoHeatingInSummerSetMissingToZero < MeterAttributeTypes::AttributeBase

    id :meter_corrections_no_heating_in_summer_set_missing_to_zero
    key :no_heating_in_summer_set_missing_to_zero
    aggregate_over :meter_corrections
    description 'Meter correction > No heating in summer set missing to zero'
    
    structure MeterAttributeTypes::Hash.define(
      structure: {
        start_toy: MeterAttributeTypes::TimeOfYear.define(required: true),
        end_toy: MeterAttributeTypes::TimeOfYear.define(required: true)
      }
    )
  end

  class RescaleAmrData < MeterAttributeTypes::AttributeBase
    id :meter_corrections_rescale_amr_data
    key :rescale_amr_data
    aggregate_over :meter_corrections
    description 'Meter correction > Rescale AMR data'
    structure MeterAttributeTypes::Hash.define(
      structure: {
        start_date: MeterAttributeTypes::Date.define(required: true),
        end_date:   MeterAttributeTypes::Date.define(required: true),
        scale:      MeterAttributeTypes::Float.define(required: true)
      }
    )
  end

  class SetMissingDataToZero < MeterAttributeTypes::AttributeBase
    id :meter_corrections_set_missing_data_to_zero
    key :set_missing_data_to_zero
    aggregate_over :meter_corrections
    description 'Meter correction > Set missing data to zero'
    structure MeterAttributeTypes::Hash.define(
      structure: {
        start_date: MeterAttributeTypes::Date.define(required: true),
        end_date:   MeterAttributeTypes::Date.define(required: true)
      }
    )
  end

  class SetBadDataToZero < MeterAttributeTypes::AttributeBase
    id :meter_corrections_set_bad_data_to_zero
    key :set_bad_data_to_zero
    aggregate_over :meter_corrections
    description 'Meter correction > Set bad data to zero'
    structure MeterAttributeTypes::Hash.define(
      structure: {
        start_date: MeterAttributeTypes::Date.define(required: true),
        end_date:   MeterAttributeTypes::Date.define(required: true)
      }
    )
  end

  class ReadingsStartDate < MeterAttributeTypes::AttributeBase
    id :meter_corrections_readings_start_date
    key :readings_start_date
    aggregate_over :meter_corrections
    description 'Meter correction > ReadingsStartDate'
    structure MeterAttributeTypes::Date.define(required: true)
  end

  class MeterCorrectionSwitch < MeterAttributeTypes::AttributeBase
    id :meter_corrections_switch
    aggregate_over :meter_corrections
    description 'Meter correction > Switch'
    structure MeterAttributeTypes::Symbol.define(required: true, allowed_values: [:set_all_missing_to_zero, :correct_zero_partial_data])
  end


  class HeatingModel < MeterAttributeTypes::AttributeBase

    id :heating_model
    key :heating_model
    description 'Heating model'

    structure MeterAttributeTypes::Hash.define(
      structure: {
        max_summer_daily_heating_kwh: MeterAttributeTypes::Integer.define(required: true),
        fitting: MeterAttributeTypes::Hash.define(
          required: false,
          structure: {
            fit_model_start_date:           MeterAttributeTypes::Date.define,
            fit_model_end_date:             MeterAttributeTypes::Date.define,
            expiry_date_of_override:        MeterAttributeTypes::Date.define,
            use_dates_for_model_validation: MeterAttributeTypes::Boolean.define
          }
        )
      }
    )
  end

  class AggregationSwitch < MeterAttributeTypes::AttributeBase

    id :aggregation_switch
    aggregate_over :aggregation
    description 'Aggregation > Switch'

    structure MeterAttributeTypes::Symbol.define(required: true, allowed_values: [:ignore_start_date, :deprecated_include_but_ignore_start_date, :deprecated_include_but_ignore_end_date])
  end

  class FunctionSwitch < MeterAttributeTypes::AttributeBase

    id :function_switch
    aggregate_over :function
    description 'Function > Switch'

    structure MeterAttributeTypes::Symbol.define(required: true, allowed_values: [:heating_only, :kitchen_only, :hotwater_only])
  end

  class Tariff < MeterAttributeTypes::AttributeBase

    id :tariff
    key :tariff
    description 'Tariff'

    structure MeterAttributeTypes::Hash.define(
      structure: {
        type: MeterAttributeTypes::Symbol.define(required: true, allowed_values: [:economy_7])
      }
    )
  end

  class SolarPV < MeterAttributeTypes::AttributeBase

    id :solar_pv
    key :solar_pv
    description 'Solar PV'

    structure MeterAttributeTypes::Hash.define(
      structure: {
        start_date:         MeterAttributeTypes::Date.define,
        end_date:           MeterAttributeTypes::Date.define,
        kwp:                MeterAttributeTypes::Float.define,
        orientation:        MeterAttributeTypes::Integer.define,
        tilt:               MeterAttributeTypes::Integer.define,
        shading:            MeterAttributeTypes::Integer.define,
        fit_£_per_kwh:      MeterAttributeTypes::Float.define
      }
    )
  end

  class LowCarbonHub < MeterAttributeTypes::AttributeBase

    id :low_carbon_hub_meter_id
    key :low_carbon_hub_meter_id
    description 'Low carbon hub meter ID'

    structure MeterAttributeTypes::Integer.define(required: true, min: 0)

  end

  class StorageHeaters < MeterAttributeTypes::AttributeBase
    id :storage_heaters
    key :storage_heaters
    description 'Storage heaters'

    structure MeterAttributeTypes::Hash.define(
      structure: {
        start_date:         MeterAttributeTypes::Date.define,
        end_date:           MeterAttributeTypes::Date.define,
        power_kw:           MeterAttributeTypes::Float.define,
        charge_start_time:  MeterAttributeTypes::TimeOfDay.define,
        charge_end_time:    MeterAttributeTypes::TimeOfDay.define
      }
    )
  end

  def self.all
    constants.inject({}) do |collection, constant_name|
      constant = const_get(constant_name)
      collection[constant.attribute_id] = constant
      collection
    end
  end


end
