require_relative './meter_attribute_types'
class MeterAttributes

  class AutoInsertMissingReadings < MeterAttributeTypes::AttributeBase

    id :meter_corrections_auto_insert_missing_readings
    key :auto_insert_missing_readings
    aggregate_over :meter_corrections

    name 'Meter correction > Auto insert missing readings'
    description 'A meter correction that uses past data to fill in readings that are missing. Useful for schools with flaky meters.'


    structure MeterAttributeTypes::Hash.define(
      structure: {
        type: MeterAttributeTypes::Symbol.define(allowed_values: [:weekends], required: true)
      }
    )
  end

  class NoHeatingInSummerSetMissingToZero < MeterAttributeTypes::AttributeBase

    id :meter_corrections_no_heating_in_summer_set_missing_to_zero
    key :no_heating_in_summer_set_missing_to_zero
    aggregate_over :meter_corrections
    name 'Meter correction > No heating in summer set missing to zero'

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
    name 'Meter correction > Rescale AMR data'
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
    name 'Meter correction > Set missing data to zero'
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
    name 'Meter correction > Set bad data to zero'
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
    name 'Meter correction > Readings start date'
    structure MeterAttributeTypes::Date.define(required: true)
  end

  class ReadingsEndDate < MeterAttributeTypes::AttributeBase
    id :meter_corrections_readings_end_date
    key :readings_end_date
    aggregate_over :meter_corrections
    name 'Meter correction > Readings end date'
    structure MeterAttributeTypes::Date.define(required: true)
  end

  class MeterCorrectionSwitch < MeterAttributeTypes::AttributeBase
    id :meter_corrections_switch
    aggregate_over :meter_corrections
    name 'Meter correction > Switch'
    structure MeterAttributeTypes::Symbol.define(required: true, allowed_values: [:set_all_missing_to_zero, :correct_zero_partial_data])
  end


  class HeatingModel < MeterAttributeTypes::AttributeBase

    id :heating_model
    key :heating_model
    name 'Heating model'

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
    name 'Aggregation > Switch'

    structure MeterAttributeTypes::Symbol.define(required: true, allowed_values: [:ignore_start_date, :deprecated_include_but_ignore_start_date, :deprecated_include_but_ignore_end_date])
  end

  class FunctionSwitch < MeterAttributeTypes::AttributeBase

    id :function_switch
    aggregate_over :function
    name 'Function > Switch'

    structure MeterAttributeTypes::Symbol.define(required: true, allowed_values: [:heating_only, :kitchen_only, :hotwater_only])
  end

  class Tariff < MeterAttributeTypes::AttributeBase

    id :tariff
    key :tariff
    name 'Tariff'

    structure MeterAttributeTypes::Hash.define(
      structure: {
        type: MeterAttributeTypes::Symbol.define(required: true, allowed_values: [:economy_7])
      }
    )
  end

  class SolarPV < MeterAttributeTypes::AttributeBase

    id :solar_pv
    aggregate_over :solar_pv
    name 'Solar PV'

    structure MeterAttributeTypes::Hash.define(
      structure: {
        start_date:         MeterAttributeTypes::Date.define,
        end_date:           MeterAttributeTypes::Date.define,
        kwp:                MeterAttributeTypes::Float.define,
        orientation:        MeterAttributeTypes::Integer.define(hint: 'in degrees'),
        tilt:               MeterAttributeTypes::Integer.define,
        shading:            MeterAttributeTypes::Integer.define,
        fit_£_per_kwh:      MeterAttributeTypes::Float.define
      }
    )
  end

  class LowCarbonHub < MeterAttributeTypes::AttributeBase

    id :low_carbon_hub_meter_id
    key :low_carbon_hub_meter_id
    name 'Low carbon hub meter ID'

    structure MeterAttributeTypes::Integer.define(required: true, min: 0)

  end

  class StorageHeaters < MeterAttributeTypes::AttributeBase
    id :storage_heaters
    aggregate_over :storage_heaters
    name 'Storage heaters'

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

  class EconomicTariff < MeterAttributeTypes::AttributeBase
    id :economic_tariff
    key :economic_tariff

    name 'Economic tariff'

    structure MeterAttributeTypes::Hash.define(
      structure: {
        name:       MeterAttributeTypes::String.define,
        rates:      MeterAttributeTypes::Hash.define(
          required: true,
          structure: {
            rate: MeterAttributeTypes::Hash.define(
              required: true,
              structure: {
                per:  MeterAttributeTypes::Symbol.define(required: true, allowed_values: [:kwh]),
                rate: MeterAttributeTypes::Float.define(required: true)
              }
            ),
            daytime_rate: MeterAttributeTypes::Hash.define(
              required: false,
              structure: {
                per:  MeterAttributeTypes::Symbol.define(allowed_values: [:kwh]),
                rate: MeterAttributeTypes::Float.define,
                from: MeterAttributeTypes::TimeOfDay.define,
                to:   MeterAttributeTypes::TimeOfDay.define
              }
            ),
            nighttime_rate: MeterAttributeTypes::Hash.define(
              required: false,
              structure: {
                per:  MeterAttributeTypes::Symbol.define(allowed_values: [:kwh]),
                rate: MeterAttributeTypes::Float.define,
                from: MeterAttributeTypes::TimeOfDay.define,
                to:   MeterAttributeTypes::TimeOfDay.define
              }
            )
          }
        )

      }
    )
  end

  class AccountingTariff < MeterAttributeTypes::AttributeBase
    id :accounting_tariff
    aggregate_over :accounting_tariffs
    name 'Accounting tariff'

    structure MeterAttributeTypes::Hash.define(
      structure: {
        start_date: MeterAttributeTypes::Date.define,
        end_date:   MeterAttributeTypes::Date.define,
        name:       MeterAttributeTypes::String.define,
        default:    MeterAttributeTypes::Boolean.define(hint: 'Enable for group/site-wide tariffs where tariff is used as a fallback'),
        rates:      MeterAttributeTypes::Hash.define(
          required: true,
          structure: {
            standing_charge: MeterAttributeTypes::Hash.define(
              required: true,
              structure: {
                per:  MeterAttributeTypes::Symbol.define(required: true, allowed_values: [:quarter, :day]),
                rate: MeterAttributeTypes::Float.define(required: true)
              }
            ),
            renewable_energy_obligation: MeterAttributeTypes::Hash.define(
              structure: {
                per:  MeterAttributeTypes::Symbol.define(allowed_values: [:kwh]),
                rate: MeterAttributeTypes::Float.define
              }
            ),
            rate: MeterAttributeTypes::Hash.define(
              structure: {
                per:  MeterAttributeTypes::Symbol.define(allowed_values: [:kwh]),
                rate: MeterAttributeTypes::Float.define
              }
            )
          }
        ),
      }
    )
  end

  class AccountingTariffDifferential < MeterAttributeTypes::AttributeBase
    id :accounting_tariff_differential
    aggregate_over :accounting_tariffs
    name 'Accounting tariff (differential)'

    structure MeterAttributeTypes::Hash.define(
      structure: {
        start_date: MeterAttributeTypes::Date.define,
        end_date:   MeterAttributeTypes::Date.define,
        name:       MeterAttributeTypes::String.define,
        default:    MeterAttributeTypes::Boolean.define(hint: 'Enable for group/site-wide tariffs where tariff is used as a fallback'),
        rates:      MeterAttributeTypes::Hash.define(
          required: true,
          structure: {
            standing_charge: MeterAttributeTypes::Hash.define(
              required: true,
              structure: {
                per:  MeterAttributeTypes::Symbol.define(required: true, allowed_values: [:quarter, :day]),
                rate: MeterAttributeTypes::Float.define(required: true)
              }
            ),
            renewable_energy_obligation: MeterAttributeTypes::Hash.define(
              structure: {
                per:  MeterAttributeTypes::Symbol.define(allowed_values: [:quarter, :day]),
                rate: MeterAttributeTypes::Float.define
              }
            ),
            daytime_rate: MeterAttributeTypes::Hash.define(
              required: true,
              structure: {
                per:  MeterAttributeTypes::Symbol.define(required: true, allowed_values: [:kwh]),
                rate: MeterAttributeTypes::Float.define(required: true),
                from: MeterAttributeTypes::TimeOfDay.define(required: true),
                to:   MeterAttributeTypes::TimeOfDay.define(required: true),
              }
            ),
            nighttime_rate: MeterAttributeTypes::Hash.define(
              required: true,
              structure: {
                per:  MeterAttributeTypes::Symbol.define(required: true, allowed_values: [:kwh]),
                rate: MeterAttributeTypes::Float.define(required: true),
                from: MeterAttributeTypes::TimeOfDay.define(required: true),
                to:   MeterAttributeTypes::TimeOfDay.define(required: true),
              }
            )
          }
        ),
        asc_limit_kw: MeterAttributeTypes::Float.define

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
