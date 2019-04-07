require_relative '../../lib/dashboard/time_of_year.rb'
require_relative '../../lib/dashboard/time_of_day.rb'
require 'awesome_print'
require 'date'
# temporary class to enhance meter data model prior to this data being
# stored in the database, and ensure PH's YAML meter representation
# which already holds this data stays in sync with postgres
class MeterAttributes
  extend Logging

  def self.for(mpan_mprn, area_name, fuel_type)
    mpan_mprn = mpan_mprn.to_i
    attributes = METER_ATTRIBUTE_DEFINITIONS.key?(mpan_mprn) ? METER_ATTRIBUTE_DEFINITIONS[mpan_mprn] : {}

    if area_name.include?('Bath') && fuel_type == :gas
      weekend_correction = { auto_insert_missing_readings: { type: :weekends }}

      if attributes.key?(:meter_corrections)
        unless attributes[:meter_corrections].detect { |h| h.is_a?(Hash) && h.key?(:auto_insert_missing_readings) }
          attributes[:meter_corrections] << weekend_correction
        end
      else
        attributes[:meter_corrections] = [weekend_correction]
      end
    end
    attributes
  end

  METER_ATTRIBUTE_DEFINITIONS = {
    # ==============================Athlestan=============================
    2148244308  => {
      heating_model: {
        max_summer_daily_heating_kwh:     800,
        reason: 'Automated process set too high at about 1500'
      }
    },
    # ==============================Bishop Sutton==============================
    2200012833349 => {
      aggregation:  [
        :deprecated_include_but_ignore_end_date,
        :deprecated_include_but_ignore_start_date
      ],
      meter_corrections: [
        no_heating_in_summer_set_missing_to_zero: {
          start_toy: TimeOfYear.new(5,25),
          end_toy:   TimeOfYear.new(10, 15)
        },
        readings_end_date: Date.new(2016, 9, 30)
      ],
      function: [ :heating_only ]
    },
    2200012833358 => {
      meter_corrections: [
        readings_end_date: Date.new(2017, 9, 30)
      ]
    },
    # ==============================Castle Primary=============================
    2200015105145 => {
      aggregation:  [
        :deprecated_include_but_ignore_end_date,
        :deprecated_include_but_ignore_start_date
      ]
    },
    2200015105163 => {
      aggregation:  [
        :deprecated_include_but_ignore_end_date,
        :deprecated_include_but_ignore_start_date
      ]
    },
    2200041803451 => { aggregation:  [:deprecated_include_but_ignore_end_date] },
    2200042676990 => { aggregation:  [:ignore_start_date] }, # succeeds meters above
    4186869705 => {
      heating_model: {
        max_summer_daily_heating_kwh:     400,
        reason: 'Automated process set too high at about 600'
      },
      meter_corrections: [
        {
          rescale_amr_data: {
            start_date: Date.new(2014, 11, 3),
            end_date: Date.new(2014, 11, 19),
            scale:  0.25 # arbitrary scaling down of data PH doesn't understand
          }
        }
      ]
    },
    # ==============================Critchall============================
    2000025766279 => {
      meter_corrections: [ :correct_zero_partial_data ]
    },
    # ==============================Eccleshall=============================
    2155853706  => {
      heating_model: {
        max_summer_daily_heating_kwh:     400,
        reason: 'Automated process set too high at about 1000'
      }
    },
    # ==============================Frome College============================
    2000027481429 => {
      meter_corrections: [ :correct_zero_partial_data ]
    },
    # ==============================Hunters Bar=============================
    6512204 => {
      aggregation:  [
        :deprecated_include_but_ignore_end_date,
        :deprecated_include_but_ignore_start_date
      ]
    },
    # ==============================King Edward VI =============================
    6517203  => {
      meter_corrections: [
        {
          readings_start_date: Date.new(2018, 2, 15)
        }
      ],
      heating_model: {
        max_summer_daily_heating_kwh:     2000,
        reason: 'Automated process set too high at about 6800'
      }
    },
    # ==============================Marksbury==================================
    2200011879013 => {
      meter_corrections: [
        {
          readings_start_date: Date.new(2011, 10, 20),
          reason: 'For some reason all data was set as an attibute to zero historically, changed 3Mar2019 PH'
        }
      ]
    },
    # ==============================Mundella Primary School=============================
    9091095306 => {
      meter_corrections: [
        {
          set_missing_data_to_zero: { # blank data in this range, perhaps shouldn't be zeroed, but largely holidays?
            start_date: Date.new(2016, 7, 12),
            end_date:   Date.new(2016, 9, 16)
          }
        }
      ],
      aggregation:  [
        :deprecated_include_but_ignore_start_date
      ]
    },
    # ==============================Paulton Junior=============================
    13678903 => {
      meter_corrections: [
        {
          set_bad_data_to_zero: {
            start_date: Date.new(2016, 4, 27),
            end_date:   Date.new(2016, 4, 27)
          },
        },
        {
          readings_start_date: Date.new(2014, 9, 30)
        }
      ],
      heating_model: {
        max_summer_daily_heating_kwh:     150,
        reason: 'Automated process set too high at about 400'
      }
    },
    2200011955152 => {
      solar_pv: [  # and array to cope with multiple installations at different times at the same school e.g. Newbridge
        {
          start_date:         Date.new(2014, 1, 1),
          # end_date:          Date.new(2025, 1, 1),
          kwp:                6.0, # appears to have 22 panels on bing satellite - for 2016 extension
          orientation:        0,
          tilt:               30,
          shading:            0,
          fit_£_per_kwh:      0.30
        }
      ]
    },
    # ==============================Roundhill==================================
    75665806 => {
      meter_corrections: [
        {
          rescale_amr_data: {
            start_date: Date.new(2009, 1, 1),
            end_date: Date.new(2013, 9, 1),
            scale:  (1.0 / 31.1) # incorrectly scaled imperial/metric data
          }
        }
      ],
      heating_model: {
        max_summer_daily_heating_kwh:     80,
        reason: 'There seems to be some occasional noise, which is unidentified but not heating PH(4Mar2019)'
      }
    },
    50974703 => {
      meter_corrections: [
        {
          rescale_amr_data: {
            start_date: Date.new(2009, 1, 1),
            end_date: Date.new(2011, 7, 25),
            scale:  (1.0 / 31.1) # incorrectly scaled imperial/metric data
          }
        }
      ],
      heating_model: {
        max_summer_daily_heating_kwh:     330,
        reason: 'Difficult to split heating and HW, auto split around 800 PH(4Mar2019)'
      }
    },
    50974602 => {
      meter_corrections: [
        {
          rescale_amr_data: {
            start_date: Date.new(2010, 9, 4),
            end_date: Date.new(2011, 9, 4),
            scale:  (1.0 / 31.1) # incorrectly scaled imperial/metric data
          }
        }
      ],
      reason: 'may need to be set to heating model, as kitchen seems outside temperature dependent, 2x reduction in usage post Jul 2018 PH(4Mar2019)'
    },
    75665705 => {
      meter_corrections: [
        {
          rescale_amr_data: {
            start_date: Date.new(2010, 9, 4),
            end_date: Date.new(2011, 9, 4),
            scale:  (1.0 / 31.1) # incorrectly scaled imperial/metric data
          }
        }
      ],
      heating_model: {
        max_summer_daily_heating_kwh:     90,
        reason: 'Auto fitter slightly high at 105 PH(4Mar2019)'
      }
    },
    80000000109005 => {
      heating_model: {
        max_summer_daily_heating_kwh:     600,
        reason: 'Auto fitter high at 1400 PH(4Mar2019)'
      }
    },
    # ==============================St Johns===============================
    9206222810 => {
      meter_corrections: [ { readings_start_date: Date.new(2017, 2, 21) } ],
      heating_model: {
        max_summer_daily_heating_kwh:     250,
        reason: 'Automated process set too high at about 450'
      }
    },
    # ==============================St Louis===============================
    19161200 => {
      function: [ :heating_only ]
    },
    # ==============================St Marks===================================
    8841599005 => { # gas Heating 1
      meter_corrections: [
        no_heating_in_summer_set_missing_to_zero: {
          start_toy: TimeOfYear.new(4, 1),
          end_toy:   TimeOfYear.new(9, 30)
        }
      ]
      # function: [ :heating_only ]
    },
    13684909 => { # gas Heating 2
      meter_corrections: [
        {
          no_heating_in_summer_set_missing_to_zero: {
            start_toy: TimeOfYear.new(4, 1),
            end_toy:   TimeOfYear.new(9, 30)
          }
        },
        {
          rescale_amr_data: {
            start_date: Date.new(2009, 1, 1),
            end_date: Date.new(2012, 2, 12),
            scale:  (1.0 / 31.1) # incorrectly scaled imperial/metric data
          }
        }
      ],
      function: [:heating_only]
    },
    13685103 => { # gas Orchard Lodge
      meter_corrections: [
        no_heating_in_summer_set_missing_to_zero: {
          start_toy: TimeOfYear.new(4, 1),
          end_toy:   TimeOfYear.new(9, 30)
        }
      ],
      aggregation:  [ # 17Mar2019 think Orchard Lodge no longer occupied, no gas consumption?
        :deprecated_include_but_ignore_end_date
      ],
      function: [ :heating_only ]
    },
    13685204 => { # gas kitchen
      meter_corrections: [ :set_all_missing_to_zero ],
      function: [ :kitchen_only ]
    },
    13685002 => { # gas hot water
      meter_corrections: [ :set_all_missing_to_zero ],
      function: [ :hotwater_only ]
    },
    80000000109328 => {
      heating_model: {
        max_summer_daily_heating_kwh:     850,
        reason: 'Automated process set too high at about 1500'
      }
    },
    # ==============================St Saviours Juniors========================
    4234023603 => { # current gas meter
      aggregation:  [ :ignore_start_date ]
    },
    46341710 => { # old gas meter
      aggregation:  [ :deprecated_include_but_ignore_end_date ],
      meter_corrections: [
        {
          rescale_amr_data: {
            start_date: Date.new(2009, 9, 8),
            end_date: Date.new(2015, 8, 17),
            scale:  (11.0 / 31.1) # incorrectly scaled imperial/metric data
          }
        },
        {
          set_bad_data_to_zero: {
            start_date: Date.new(2015, 7, 31),
            end_date:   Date.new(2015, 8, 17)
          }
        }
      ]
    },
    2200012408737 => { # current electricity meter
      aggregation:  [ :ignore_start_date ]
    },
    2200012408773 => { # deprecated electricity meter
      aggregation:  [
        :deprecated_include_but_ignore_end_date,
        :deprecated_include_but_ignore_start_date
      ]
    },
    2200012408791 => { # deprecated electricity meter
      aggregation:  [ :deprecated_include_but_ignore_end_date ]
    },
    2200012408782 => { # deprecated electricity meter
      aggregation:  [ :deprecated_include_but_ignore_end_date ]
    },
    2200012408816 => { # deprecated electricity meter
      aggregation:  [
        :deprecated_include_but_ignore_end_date,
        :deprecated_include_but_ignore_start_date
      ]
    },
    # ==============================St Martins========================
    80000000133290 => {
      heating_model: {
        max_summer_daily_heating_kwh:     650,
        reason: 'Automated process set too high at about 1400'
      }
    },
    # ==============================Saltford========================
    47939506 => {
      heating_model: {
        max_summer_daily_heating_kwh:     100,
        reason:                           'heating only since 2018, cant set as not so in past: PH 4Mar2019'
      },
=begin
      # example of tested manual model override, for which support required
      # when atributes are absorbed into front end
      heating_model: {
        max_summer_daily_heating_kwh:     400,
        # override_best_model_type:         :simple_regression_temperature,
        override_model: {
          type:   :simple_regression_temperature,
          regression_models: {
            heating_occupied_all_days:  { a: 20000, b: -45, base_temperature: 20.0 },
            weekend_heating:            { a: 252, b: -11, base_temperature: 20.0 },
            holiday_heating:            { a: 300, b: -20, base_temperature: 20.0 },
            none:                       { a: 0, b: 0, base_temperature: 20.0 },
            summer_occupied_all_days:   { a: 100, b: 0, base_temperature: 20.0 },
            weekend_hotwater_only:      { a: 80, b: 0, base_temperature: 20.0 },
            holiday_hotwater_only:      { a: 90, b: 0, base_temperature: 20.0 }
          }
        },
        reason: 'Saltford has strange gas consumption data, this is a test'
      },
=end
      # function: [:heating_only] - although its currently heating only (2018-19) it wasn't in the past
    },
    # ==============================Stanton Drew========================
    2200013463696 => {
      meter_corrections: [
        {
          readings_start_date: Date.new(2010, 6, 25),
          reason: 'Probably not needed, LGAP lost during testing of bulk upload PH 4Mar2019, suggest remove on further review'
        },
      ],
      heating_model: {
        max_summer_daily_heating_kwh:     25,
        reason: 'Staton Drew has strange bifurcation, suggesting half the storage heaters are switched off much earlier in the year'
      },
      tariff: {
        type:             :economy_7 # this isn't really the case for Stanton Drew as runs off flat tariff but it will do for testing
      },
      storage_heaters: [  # an array so you can change the config for different time periods
        {                 # the contents of the hash are all optional, so can set the config to storage_heaters: nil for simplicity
          start_date:         Date.new(2010, 1, 1),   # not strictly necessary, included for testing purposes, if missing assumes 'forever'
          end_date:           Date.new(2025, 1, 1),   # not strictly necessary, included for testing purposes, if missing assumes 'forever'
          power_kw:           22.0,                   # not strictly necessary, included for testing purposes
          charge_start_time:  TimeOfDay.new(0, 30),   # optional
          charge_end_time:    TimeOfDay.new(6, 30),   # optional
          days_of_week:       ['Sunday', 'Monday', 'Tuesday', 'Wednesday', 'Saturday'] # suspect this isn't required/not supported
        }
      ]
    },
    # ==============================Trinity============================
    2000025766288 => {
      meter_corrections: [ :correct_zero_partial_data ]
    },
    # ==============================Twerton========================
    4223705708 => {
      heating_model: {
        max_summer_daily_heating_kwh:     250,
        reason: 'Automated process set too high at about 350'
      }
    },
    # ==============================Whiteways========================
    2163409301 => {
      heating_model: {
        max_summer_daily_heating_kwh:     1000,
        reason: 'Automated process set too high at about 1200'
      }
    },
    # ==============================Woodthorpe========================
    9120550903 => {
      heating_model: {
        max_summer_daily_heating_kwh:     500,
        reason: 'Automated process set too high at about 750'
      }
    },
    # ==============================Wycliffe========================
    9209120604 => {
      heating_model: {
        max_summer_daily_heating_kwh:     350,
        reason: 'Automated process set too high at about 550'
      }
    },

  }.freeze
end
