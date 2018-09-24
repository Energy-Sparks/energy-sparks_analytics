require_relative '../../lib/dashboard/time_of_year.rb'
require 'awesome_print'
require 'date'
# temporary class to enhance meter data model prior to this data being
# stored in the database, and ensure PH's YAML meter representation
# which already holds this data stays in sync with postgres
class MeterAttributes
  extend Logging

  def self.attributes(mpan_or_mprn, type)
    return nil unless METER_ATTRIBUTE_DEFINITIONS.key?(mpan_or_mprn)
    return nil unless METER_ATTRIBUTE_DEFINITIONS[mpan_or_mprn].key?(type)
    METER_ATTRIBUTE_DEFINITIONS[mpan_or_mprn][type]
  end

  METER_ATTRIBUTE_DEFINITIONS = {
    # ==============================St Marks===================================
    8841599005 => { # gas Heating 1
      meter_corrections: [
        no_heating_in_summer_set_missing_to_zero: {
          start_toy: TimeOfYear.new(4, 1),
          end_toy:   TimeOfYear.new(9, 30)
        }
      ],
      function: [ :heating_only ]
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
    }
  }.freeze
  private_constant :METER_ATTRIBUTE_DEFINITIONS
end
