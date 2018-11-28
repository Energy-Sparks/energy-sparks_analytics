require_relative '../../lib/dashboard/time_of_year.rb'
require 'awesome_print'
require 'date'
# temporary class to enhance meter data model prior to this data being
# stored in the database, and ensure PH's YAML meter representation
# which already holds this data stays in sync with postgres
class MeterAttributes
  extend Logging

  def self.attributes(meter, type)
    mpan_mprn = meter.mpan_mprn.to_i # treat as integer even if loaded as string
    return nil unless METER_ATTRIBUTE_DEFINITIONS.key?(mpan_mprn)
    return nil unless METER_ATTRIBUTE_DEFINITIONS[mpan_mprn].key?(type)

    butes = METER_ATTRIBUTE_DEFINITIONS[mpan_mprn][type]

    # fill in weekends for all Bath derived data
    if type == :meter_corrections && meter.building.area_name == 'Bath'
      butes.push( {auto_insert_missing_readings: { type: :weekends}})
    end
    butes
  end

  METER_ATTRIBUTE_DEFINITIONS = { 
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
        }
      ],
      function: [ :heating_only ]
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
 #       calculation_start_date: nil,
 #       calculation_end_date:   nil,
        heating_day_determination_method:  { fixed__minimum_per_day: 250 },
        heating_balance_point_temperature:  16.0,
        model: :thermally_heavy,
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
    # ==============================Marksbury==================================
    2200011879013 => {
      meter_corrections: [
        {
          set_bad_data_to_zero: {
            start_date: Date.new(2011, 10, 6),
            end_date:   Date.new(2015, 10, 17)
          }
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
      ]
    },
    # ==============================Roundhill==================================
    75665806 => {
      meter_corrections: [
        {
          rescale_amr_data: {
            start_date: Date.new(2009, 1, 1),
            end_date: Date.new(2009, 1, 1),
            scale:  (1.0 / 31.1) # incorrectly scaled imperial/metric data
          }
        }
      ]
    },
    # ==============================St Johns===============================
    9206222810 => {
      meter_corrections: [ { readings_start_date: Date.new(2017, 2, 21) } ]
    },
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
