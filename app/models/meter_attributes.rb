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

  class OverrideBadReadings < MeterAttributeTypes::AttributeBase
    id :meter_corrections_override_bad_readings
    key :override_bad_readings
    aggregate_over :meter_corrections
    name 'Meter correction > Substitute bad readings'
    structure MeterAttributeTypes::Hash.define(
      structure: {
        start_date: MeterAttributeTypes::Date.define(required: true),
        end_date:   MeterAttributeTypes::Date.define(required: true)
      }
    )
  end

  class ExtendMeterReadingsForSubstitution < MeterAttributeTypes::AttributeBase
    id :meter_corrections_extend_meter_readings_for_substitution
    key :extend_meter_readings_for_substitution
    aggregate_over :meter_corrections
    name 'Meter correction > Extend meter reading range for substitutions'
    structure MeterAttributeTypes::Hash.define(
      structure: {
        start_date: MeterAttributeTypes::Date.define(required: false),
        end_date:   MeterAttributeTypes::Date.define(required: false)
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

  class PartialMeterFloorAreaPupilNumbersolar_pvOverride < MeterAttributeTypes::AttributeBase
    id :partial_meter_coverage
    key :partial_meter_coverage
    aggregate_over :partial_meter_coverage
    name 'Override percent of floor area or pupil numbers covered by meter'
    structure MeterAttributeTypes::Hash.define(
      structure: {
        start_date: MeterAttributeTypes::Date.define,
        end_date:   MeterAttributeTypes::Date.define,
        percent_floor_area:      MeterAttributeTypes::Float.define(required: true),
        percent_pupil_numbers:   MeterAttributeTypes::Float.define(required: true)
      }
    )
  end

  class StorageHeaterPartialMeterFloorAreaPupilNumberOverride < MeterAttributeTypes::AttributeBase
    id :storage_heater_partial_meter_coverage
    key :storage_heater_partial_meter_coverage
    aggregate_over :storage_heater_partial_meter_coverage
    name 'Override percent of floor area or pupil numbers covered by meter - storage heaters only'
    structure MeterAttributeTypes::Hash.define(
      structure: {
        start_date: MeterAttributeTypes::Date.define,
        end_date:   MeterAttributeTypes::Date.define,
        percent_floor_area:      MeterAttributeTypes::Float.define(required: true),
        percent_pupil_numbers:   MeterAttributeTypes::Float.define(required: true)
      }
    )
  end

  class FloorAreaPupilNumbersChangeOverTimeOverride < MeterAttributeTypes::AttributeBase
    id :floor_area_pupil_numbers
    aggregate_over :floor_area_pupil_numbers
    name 'Changing floor area and pupil numbers over time'
    structure MeterAttributeTypes::Hash.define(
      structure: {
        start_date:       MeterAttributeTypes::Date.define,
        end_date:         MeterAttributeTypes::Date.define,
        floor_area:       MeterAttributeTypes::Float.define(required: true),
        number_of_pupils: MeterAttributeTypes::Float.define(required: true)
      }
    )
  end

  class SchoolFabricDescription < MeterAttributeTypes::AttributeBase
    id :school_fabric
    aggregate_over :school_fabric
    name 'Genric school fabric information for audit purposes'
    structure MeterAttributeTypes::Hash.define(
      structure: {
        type:       MeterAttributeTypes::String.define(required: true),
        description: MeterAttributeTypes::String.define(required: true)
      }
    )
  end

  class PartialMeterFloorAreaPupilNumberDateRangeOverride < MeterAttributeTypes::AttributeBase
    id :partial_meter_coverage_date_range
    key :partial_meter_coverage_date_range
    aggregate_over :meter_corrections
    name 'Override percent of floor area or pupil numbers covered by meter - with date ranges'
    structure MeterAttributeTypes::Hash.define(
      structure: {
        start_date: MeterAttributeTypes::Date.define(required: true),
        end_date:   MeterAttributeTypes::Date.define(required: true),
        percent_floor_area:      MeterAttributeTypes::Float.define(required: true),
        percent_pupil_numbers:   MeterAttributeTypes::Float.define(required: true)
      }
    )
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

  class SolarPVOverrides < SolarPV

    id :solar_pv_override
    aggregate_over :solar_pv_override
    name 'Override bad metered solar pv data'
    structure MeterAttributeTypes::Hash.define(
      structure: {
        start_date:             MeterAttributeTypes::Date.define,
        end_date:               MeterAttributeTypes::Date.define,
        kwp:                    MeterAttributeTypes::Float.define,
        orientation:            MeterAttributeTypes::Integer.define(hint: 'in degrees'),
        tilt:                   MeterAttributeTypes::Integer.define,
        shading:                MeterAttributeTypes::Integer.define,
        fit_£_per_kwh:          MeterAttributeTypes::Float.define,
        override_generation:    MeterAttributeTypes::Boolean.define(required: true),
        override_export:        MeterAttributeTypes::Boolean.define(required: true),
        override_self_consume:  MeterAttributeTypes::Boolean.define(required: true),
      }
    )

    # NB uses inherited attributes
  end

  class SolarPVMeterMapping < MeterAttributeTypes::AttributeBase
  
    id                  :solar_pv_mpan_meter_mapping
    aggregate_over      :solar_pv_mpan_meter_mapping
    name                'Solar PV MPAN Meter mapping'

    structure MeterAttributeTypes::Hash.define(
      structure: {
        start_date:         MeterAttributeTypes::Date.define(required: true),
        end_date:           MeterAttributeTypes::Date.define,
        export_mpan:        MeterAttributeTypes::String.define,
        production_mpan:    MeterAttributeTypes::String.define,
        self_consume_mpan:  MeterAttributeTypes::String.define
      }
    )
  end

  class SolarPVExternalMeterIdentifier < MeterAttributeTypes::AttributeBase
    id    :solar_pv_external_identifier
    key   :solar_pv_external_identifier
    name  'Solar PV External Identifier (type e.g. low_carbon_hub, id e.g. 123456)'

    structure MeterAttributeTypes::Hash.define(
      structure: {
        identifier_type:  MeterAttributeTypes::String.define(required: true),
        identifier:       MeterAttributeTypes::String.define(required: true),
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

  def self.default_tariff_rates
    {
      standing_charge: MeterAttributeTypes::Hash.define(
        required: true,
        structure: {
          per:  MeterAttributeTypes::Symbol.define(required: true, allowed_values: [:day, :month, :quarter]),
          rate: MeterAttributeTypes::Float.define(required: true)
        }
      ),
      climate_change_levy: MeterAttributeTypes::Hash.define(
        structure: {
          per:  MeterAttributeTypes::Symbol.define(allowed_values: [:kwh]),
          rate: MeterAttributeTypes::Float.define
        }
      ),
      renewable_energy_obligation: MeterAttributeTypes::Hash.define(
        structure: {
          per:  MeterAttributeTypes::Symbol.define(allowed_values: [:kwh]),
          rate: MeterAttributeTypes::Float.define
        }
      ),
      agreed_capacity: MeterAttributeTypes::Hash.define(
        structure: {
          per:  MeterAttributeTypes::Symbol.define(allowed_values: [:day, :month, :quarter]),
          rate: MeterAttributeTypes::Float.define
        }
      ),
      settlement_agency_fee: MeterAttributeTypes::Hash.define(
        structure: {
          per:  MeterAttributeTypes::Symbol.define(allowed_values: [:kwh, :day, :month, :quarter]),
          rate: MeterAttributeTypes::Float.define
        }
      ),
      reactive_power_charge: MeterAttributeTypes::Hash.define(
        structure: {
          per:  MeterAttributeTypes::Symbol.define(allowed_values: [:kwh, :day, :month, :quarter]),
          rate: MeterAttributeTypes::Float.define
        }
      ),
      half_hourly_data_charge: MeterAttributeTypes::Hash.define(
        structure: {
          per:  MeterAttributeTypes::Symbol.define(allowed_values: [:day, :month, :quarter]),
          rate: MeterAttributeTypes::Float.define
        }
      ),
      other: MeterAttributeTypes::Hash.define(
        structure: {
          per:  MeterAttributeTypes::Symbol.define(allowed_values: [:kwh, :day, :month, :quarter]),
          rate: MeterAttributeTypes::Float.define
        }
      )
    }
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
            rate: MeterAttributeTypes::Hash.define(
              required: true,
              structure: {
                per:  MeterAttributeTypes::Symbol.define(required: true, allowed_values: [:kwh]),
                rate: MeterAttributeTypes::Float.define(required: true)
              }
            )
          }.merge(MeterAttributes.default_tariff_rates)
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
          }.merge(MeterAttributes.default_tariff_rates)
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
