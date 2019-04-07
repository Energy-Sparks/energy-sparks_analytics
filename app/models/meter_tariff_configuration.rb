# configuration information for meter tariff class
class MeterTariffs
  SHEFFIELDYPOCONTRACTDATES_2015_2020 = Date.new(2015, 1, 1)..Date.new(2020, 3, 1)
  BATHCONTRACTDATES_2015_2020 = Date.new(2017, 1, 1)..Date.new(2020, 3, 1)
  FROMECONTRACTDATES_2015_2020 = Date.new(2017, 1, 1)..Date.new(2020, 3, 1)
  SOMERSETCONTRACTDATES_2015_2020 = Date.new(2017, 1, 1)..Date.new(2020, 3, 1)
  FOREVERCONTRACTDATES = Date.new(2000, 1, 1)..Date.new(2050, 1, 1)
  ECONOMY7_NIGHT_TIME_PERIOD = TimeOfDay.new(0, 0)..TimeOfDay.new(6, 30)
  ECONOMY7_DAY_TIME_PERIOD = TimeOfDay.new(6, 30)..TimeOfDay.new(24, 0)

  BILL_COMPONENTS = {
    rate: {
      summary:      'Cost per kWh',
      description:  'Cost per kWh'
    },
    daytime_rate: {
      summary:      'Cost per kWh (day time)',
      description:  'Cost per kWh - day time rate on differential (economy 7) tariff typically from 06:30 to midnight'
    },
    nighttime_rate: {
      summary:      'Cost per kWh (night time)',
      description:  'Cost per kWh - night time rate on differential (economy 7) tariff typically from midnight and 06:30'
    },
    standing_charge: {
      summary:      'Standing Charge',
      description:  'Standing Charge'
    },
    climate_change_levy: {
      summary:      'Climate Change Levy',
      description:  'Climate Change Levy (CCL) charged on all non renewable energy sources - at a fixed government rate per kWh consumed'
    },
    renewable_energy_obligation: {
      summary:      'Renewable Energy Obligation',
      description:  'Renewable Energy Obligation - at a fixed government rate per kWh consumed'
    },
    agreed_capacity: {
      summary:      'Agreed Capacity',
      description:  'Agreed Capacity: Fixed monthly payment for sites with large electricity requirements - payment for maximum electricity kVA consumed in a month'
    },
    settlement_agency_fee: {
      summary:      'Settlement Agency Fee',
      description:  'Charge for company called Elexon managing the supply and demand on the elecritcity grid'
    },
    reactive_power_charge: {
      summary:      'Reactive Power Charge',
      description:  'Charge if delivered versus converted electricity differs - typically if your site has motors and similar industrial equipment'
    },
    half_hourly_data_charge: {
      summary:      'Half Hourly Metering Charge',
      description:  'Charge for half hourly metering service'
    }
  }.freeze

  ECONOMIC_TARIFFS = { 
    electricity: {
      FOREVERCONTRACTDATES => {
        name: 'Economic standard electricity tariff',
        rates: {
          rate:  { per: :kwh,     rate: 0.12 }
        }
      }
    },
    electricity_differential: {
      FOREVERCONTRACTDATES => {
        name: 'Economic day-night electricity tariff',
        rates: {
          daytime_rate:    { per: :kwh,     rate: 0.13, time_period: ECONOMY7_DAY_TIME_PERIOD },
          nighttime_rate:  { per: :kwh,     rate: 0.08, time_period: ECONOMY7_NIGHT_TIME_PERIOD }
        }
      }
    },
    gas: {
      FOREVERCONTRACTDATES => {
        name: 'Economic gas tariff',
        rates: {
          rate:   { per: :kwh,     rate: 0.03 }
        }
      }
    }
  }.freeze
  private_constant :ECONOMIC_TARIFFS

  DEFAULT_ACCOUNTING_TARIFFS = {
    'Bath' => {
      electricity: {
        BATHCONTRACTDATES_2015_2020 => {
          name: 'B&NES standard electricity tariff',
          rates: {
            standing_charge:              { per: :quarter, rate: 38.35   },
            renewable_energy_obligation:  { per: :kwh,     rate: 0.00565 },
            rate:                         { per: :kwh,     rate: 0.115 }
          }
        }
      },
      electricity_differential: {
        BATHCONTRACTDATES_2015_2020 => {
          name: 'B&NES day-night electricity tariff',
          rates: {
            standing_charge:              { per: :quarter, rate: 38.35   },
            renewable_energy_obligation:  { per: :kwh,     rate: 0.00565 },
            daytime_rate:                 { per: :kwh,     rate: 0.12805, time_period: ECONOMY7_DAY_TIME_PERIOD },
            nighttime_rate:               { per: :kwh,     rate: 0.08736, time_period: ECONOMY7_NIGHT_TIME_PERIOD }
          }
        }
      },
      gas: {
        BATHCONTRACTDATES_2015_2020 => {
          name: 'B&NES gas tariff',
          rates: {
            standing_charge:              { per: :day,     rate: 4.00  },
            rate:                         { per: :kwh,     rate: 0.015 }
          }
        }
      }
    },

    'Sheffield' => {
      electricity: {
        SHEFFIELDYPOCONTRACTDATES_2015_2020 => {
          name: 'Sheffield standard electricity tariff',
          rates: {
            standing_charge:              { per: :quarter, rate: 38.35   },
            renewable_energy_obligation:  { per: :kwh,     rate: 0.00565 },
            rate:                         { per: :kwh,     rate: 0.115 }
          }
        }
      },
      electricity_differential: {
        SHEFFIELDYPOCONTRACTDATES_2015_2020 => {
          name: 'Sheffield day-night electricity tariff',
          rates: {
            standing_charge:              { per: :quarter, rate: 38.35   },
            renewable_energy_obligation:  { per: :kwh,     rate: 0.00565 },
            daytime_rate:                 { per: :kwh,     rate: 0.12805, time_period: ECONOMY7_DAY_TIME_PERIOD },
            nighttime_rate:               { per: :kwh,     rate: 0.08736, time_period: ECONOMY7_NIGHT_TIME_PERIOD }
          }
        }
      },
      gas: {
        SHEFFIELDYPOCONTRACTDATES_2015_2020 => {
          name: 'Sheffield gas tariff',
          rates: {
            standing_charge:              { per: :day,     rate: 4.00  },
            rate:                         { per: :kwh,     rate: 0.015 }
          }
        }
      }
    },

    'Frome' => {
      electricity: {
        FROMECONTRACTDATES_2015_2020 => {
          name: 'Somerset standard electricity tariff',
          rates: {
            standing_charge:              { per: :quarter, rate: 38.35   },
            renewable_energy_obligation:  { per: :kwh,     rate: 0.00565 },
            rate:                         { per: :kwh,     rate: 0.115 }
          }
        }
      },
      electricity_differential: {
        FROMECONTRACTDATES_2015_2020 => {
          name: 'Somerset day-night electricity tariff',
          rates: {
            standing_charge:              { per: :quarter, rate: 38.35   },
            renewable_energy_obligation:  { per: :kwh,     rate: 0.00565 },
            daytime_rate:                 { per: :kwh,     rate: 0.12805, time_period: ECONOMY7_DAY_TIME_PERIOD },
            nighttime_rate:               { per: :kwh,     rate: 0.08736, time_period: ECONOMY7_NIGHT_TIME_PERIOD }
          }
        }
      },
      gas: {
        FROMECONTRACTDATES_2015_2020 => {
          name: 'Somerset gas tariff',
          rates: {
            standing_charge:              { per: :day,     rate: 4.00  },
            rate:                         { per: :kwh,     rate: 0.015 }
          }
        }
      }
    },
  }.freeze
  private_constant :DEFAULT_ACCOUNTING_TARIFFS

  # meter specific tariffs, where tariff is unique to the meter
  # typically 'accounting tariffs', and perhaps ultimately
  # solar tariffs where there is a bespoke FIT rate?
  METER_TARIFFS = {
    # =========Bankwood Primary School========
    2333110019718 =>  {
      SHEFFIELDYPOCONTRACTDATES_2015_2020 => {
        name: 'Npower YPO 5 year electricity plan - flat rate',
        rates: {
          standing_charge:  { per: :day, rate: 6.161 },
          rate:  { per: :kwh, rate: 0.1191 }
        }
      }
    },
  
  # =========Coit Primary School========
    2332951462710 =>  {
      SHEFFIELDYPOCONTRACTDATES_2015_2020 => {
        name: 'Npower YPO 5 year electricity plan - flat rate',
        rates: {
          standing_charge:  { per: :day, rate: 6.161 },
          rate:  { per: :kwh, rate: 0.1191 }
        }
      }
    },
  
  	2332951460713 =>  {
      SHEFFIELDYPOCONTRACTDATES_2015_2020 => {
        name: 'Npower YPO 5 year electricity plan - differential rate',
        rates: {
          standing_charge:  { per: :day, rate: 6.161 },
          daytime_rate:     { per: :kwh, rate: 0.12696 , time_period: ECONOMY7_DAY_TIME_PERIOD },
          nighttime_rate:  { per: :kwh, rate: 0.08975, time_period: ECONOMY7_NIGHT_TIME_PERIOD },
        }
      }
    },
  
  # =========Ecclesfield Primary School========
    2332531911711 =>  {
      SHEFFIELDYPOCONTRACTDATES_2015_2020 => {
        name: 'Npower YPO 5 year electricity plan - differential rate',
        rates: {
          standing_charge:  { per: :day, rate: 6.161 },
          daytime_rate:     { per: :kwh, rate: 0.12696 , time_period: ECONOMY7_DAY_TIME_PERIOD },
          nighttime_rate:  { per: :kwh, rate: 0.08975, time_period: ECONOMY7_NIGHT_TIME_PERIOD },
        }
      }
    },
  
  # =========Mundella Primary School========
    2333202372710 =>  {
      SHEFFIELDYPOCONTRACTDATES_2015_2020 => {
        name: 'Npower YPO 5 year electricity plan - flat rate',
        rates: {
          standing_charge:  { per: :day, rate: 6.161 },
          rate:  { per: :kwh, rate: 0.1191 }
        }
      }
    },
  
  	2380001727391 =>  {
      SHEFFIELDYPOCONTRACTDATES_2015_2020 => {
        name: 'Npower YPO 5 year electricity plan - differential rate',
        rates: {
          standing_charge:  { per: :day, rate: 6.161 },
          daytime_rate:     { per: :kwh, rate: 0.12696 , time_period: ECONOMY7_DAY_TIME_PERIOD },
          nighttime_rate:  { per: :kwh, rate: 0.08975, time_period: ECONOMY7_NIGHT_TIME_PERIOD },
        }
      }
    },
  
  
  # =========Walkley School Tennyson School========
    2330621110711 =>  {
      SHEFFIELDYPOCONTRACTDATES_2015_2020 => {
        name: 'Npower YPO 5 year electricity plan - flat rate',
        rates: {
          standing_charge:  { per: :day, rate: 6.161 },
          rate:  { per: :kwh, rate: 0.1191 }
        }
      }
    },
  
  	2330605147010 =>  {
      SHEFFIELDYPOCONTRACTDATES_2015_2020 => {
        name: 'Npower YPO 5 year electricity plan - differential rate',
        rates: {
          standing_charge:  { per: :day, rate: 6.161 },
          daytime_rate:     { per: :kwh, rate: 0.12696 , time_period: ECONOMY7_DAY_TIME_PERIOD },
          nighttime_rate:  { per: :kwh, rate: 0.08975, time_period: ECONOMY7_NIGHT_TIME_PERIOD },
        }
      }
    },
  
  # =========Woodthorpe Primary School========
    2380000477230 =>  {
      SHEFFIELDYPOCONTRACTDATES_2015_2020 => {
        name: 'Npower YPO 5 year electricity plan - differential rate',
        rates: {
          standing_charge:  { per: :day, rate: 4.064 },
          daytime_rate:     { per: :kwh, rate: 0.11684 , time_period: ECONOMY7_DAY_TIME_PERIOD },
          nighttime_rate:  { per: :kwh, rate: 0.08826, time_period: ECONOMY7_NIGHT_TIME_PERIOD },
        }
      }
    },
  
  # =========Wybourn Primary School========
    2331301835711 =>  {
      SHEFFIELDYPOCONTRACTDATES_2015_2020 => {
        name: 'Npower YPO 5 year electricity plan - differential rate',
        rates: {
          standing_charge:  { per: :day, rate: 4.064 },
          daytime_rate:     { per: :kwh, rate: 0.11897 , time_period: ECONOMY7_DAY_TIME_PERIOD },
          nighttime_rate:  { per: :kwh, rate: 0.08826, time_period: ECONOMY7_NIGHT_TIME_PERIOD },
        }
      }
    },
  
  
  # =========Whiteways Primary========
    2334501345714 =>  {
      SHEFFIELDYPOCONTRACTDATES_2015_2020 => {
        name: 'Npower YPO 5 year electricity plan - flat rate',
        rates: {
          standing_charge:  { per: :day, rate: 6.161 },
          rate:  { per: :kwh, rate: 0.1191 }
        }
      }
    },
  
  # =========Ecclesall Primary (Previously named 'Infants')========
    2331031705716 =>  {
      SHEFFIELDYPOCONTRACTDATES_2015_2020 => {
        name: 'Npower YPO 5 year electricity plan - differential rate',
        rates: {
          standing_charge:  { per: :day, rate: 6.161 },
          daytime_rate:     { per: :kwh, rate: 0.12696 , time_period: ECONOMY7_DAY_TIME_PERIOD },
          nighttime_rate:  { per: :kwh, rate: 0.08975, time_period: ECONOMY7_NIGHT_TIME_PERIOD },
        }
      }
    },
  
  # =========Hunters Bar Infants and Juniors========
    2336531952014 =>  {
      SHEFFIELDYPOCONTRACTDATES_2015_2020 => {
        name: 'Npower YPO 5 year electricity plan - differential rate',
        rates: {
          standing_charge:  { per: :day, rate: 6.161 },
          daytime_rate:     { per: :kwh, rate: 0.12696 , time_period: ECONOMY7_DAY_TIME_PERIOD },
          nighttime_rate:  { per: :kwh, rate: 0.08975, time_period: ECONOMY7_NIGHT_TIME_PERIOD },
        }
      }
    },
  
  
  
  
  # =========Watercliffe Meadow Community Primary School========
    2380001112280 =>  {
      SHEFFIELDYPOCONTRACTDATES_2015_2020 => {
        name: 'Npower YPO 5 year electricity plan - differential rate',
        rates: {
          standing_charge:  { per: :day, rate: 4.064 },
          daytime_rate:     { per: :kwh, rate: 0.11763 , time_period: ECONOMY7_DAY_TIME_PERIOD },
          nighttime_rate:  { per: :kwh, rate: 0.08824, time_period: ECONOMY7_NIGHT_TIME_PERIOD },
        }
      }
    },
  
  # =========Athelstan Primary School========
    2335212561712 =>  {
      SHEFFIELDYPOCONTRACTDATES_2015_2020 => {
        name: 'Npower YPO 5 year electricity plan - flat rate',
        rates: {
          standing_charge:  { per: :day, rate: 6.161 },
          rate:  { per: :kwh, rate: 0.1191 }
        }
      }
    },
  
  # =========Ballifield Primary School========
    2335250725714 =>  {
      SHEFFIELDYPOCONTRACTDATES_2015_2020 => {
        name: 'Npower YPO 5 year electricity plan - differential rate',
        rates: {
          standing_charge:  { per: :day, rate: 6.161 },
          daytime_rate:     { per: :kwh, rate: 0.12696 , time_period: ECONOMY7_DAY_TIME_PERIOD },
          nighttime_rate:  { per: :kwh, rate: 0.08975, time_period: ECONOMY7_NIGHT_TIME_PERIOD },
        }
      }
    },
  
  # =========Lydgate Junior school========
    2330741676714 =>  {
      SHEFFIELDYPOCONTRACTDATES_2015_2020 => {
        name: 'Npower YPO 5 year electricity plan - differential rate',
        rates: {
          standing_charge:  { per: :day, rate: 6.161 },
          daytime_rate:     { per: :kwh, rate: 0.12696 , time_period: ECONOMY7_DAY_TIME_PERIOD },
          nighttime_rate:  { per: :kwh, rate: 0.08975, time_period: ECONOMY7_NIGHT_TIME_PERIOD },
        }
      }
    },
  
  # =========Arbourthorne Community Primary========
    2380000442901 =>  {
      SHEFFIELDYPOCONTRACTDATES_2015_2020 => {
        name: 'Npower YPO 5 year electricity plan - differential rate',
        rates: {
          standing_charge:  { per: :day, rate: 4.064 },
          daytime_rate:     { per: :kwh, rate: 0.1201 , time_period: ECONOMY7_DAY_TIME_PERIOD },
          nighttime_rate:  { per: :kwh, rate: 0.08826, time_period: ECONOMY7_NIGHT_TIME_PERIOD },
        }
      }
    },
  
  # =========King Edwards Upper========
    2380001640466 =>  {
      SHEFFIELDYPOCONTRACTDATES_2015_2020 => {
        name: 'Npower YPO 5 year electricity plan - differential rate',
        rates: {
          standing_charge:  { per: :day, rate: 4.064 },
          daytime_rate:     { per: :kwh, rate: 0.11634 , time_period: ECONOMY7_DAY_TIME_PERIOD },
          nighttime_rate:  { per: :kwh, rate: 0.08823, time_period: ECONOMY7_NIGHT_TIME_PERIOD },
        }
      }
    },
  
  	2330400572210 =>  {
      SHEFFIELDYPOCONTRACTDATES_2015_2020 => {
        name: 'Npower YPO 5 year electricity plan - flat rate',
        rates: {
          standing_charge:  { per: :day, rate: 6.076 },
          rate:  { per: :kwh, rate: 0.1246 }
        }
      }
    },
    # =========Bankwood Primary School========
    6326701 =>  {
      SHEFFIELDYPOCONTRACTDATES_2015_2020 => {
        name:  'Corona Sheffield YPO 5 year gas plan',
        rates:  {
          standing_charge:  { per: :day, rate: 8.68 },
          rate:  { per: :kwh, rate: 0.020422 }
        }
      }
    },
  
  # =========Coit Primary School========
    6460705 =>  {
      SHEFFIELDYPOCONTRACTDATES_2015_2020 => {
        name:  'Corona Sheffield YPO 5 year gas plan',
        rates:  {
          standing_charge:  { per: :day, rate: 4.81 },
          rate:  { per: :kwh, rate: 0.020422 }
        }
      }
    },
  
  
  # =========Ecclesfield Primary School========
    6554602 =>  {
      SHEFFIELDYPOCONTRACTDATES_2015_2020 => {
        name:  'Corona Sheffield YPO 5 year gas plan',
        rates:  {
          standing_charge:  { per: :day, rate: 5.6 },
          rate:  { per: :kwh, rate: 0.020422 }
        }
      }
    },
  
  # =========Mundella Primary School========
    9091095306 =>  {
      SHEFFIELDYPOCONTRACTDATES_2015_2020 => {
        name:  'Corona Sheffield YPO 5 year gas plan',
        rates:  {
          standing_charge:  { per: :day, rate: 2.92 },
          rate:  { per: :kwh, rate: 0.020422 }
        }
      }
    },
  
  	6319210 =>  {
      SHEFFIELDYPOCONTRACTDATES_2015_2020 => {
        name:  'Corona Sheffield YPO 5 year gas plan',
        rates:  {
          standing_charge:  { per: :day, rate: 1.94 },
          rate:  { per: :kwh, rate: 0.020422 }
        }
      }
    },
  
  	6319300 =>  {
      SHEFFIELDYPOCONTRACTDATES_2015_2020 => {
        name:  'Corona Sheffield YPO 5 year gas plan',
        rates:  {
          standing_charge:  { per: :day, rate: 2.16 },
          rate:  { per: :kwh, rate: 0.020422 }
        }
      }
    },
  
  # =========Walkley School Tennyson School========
    9337391909 =>  {
      SHEFFIELDYPOCONTRACTDATES_2015_2020 => {
        name:  'Corona Sheffield YPO 5 year gas plan',
        rates:  {
          standing_charge:  { per: :day, rate: 4.99 },
          rate:  { per: :kwh, rate: 0.020422 }
        }
      }
    },
  
  	6500803 =>  {
      SHEFFIELDYPOCONTRACTDATES_2015_2020 => {
        name:  'Corona Sheffield YPO 5 year gas plan',
        rates:  {
          standing_charge:  { per: :day, rate: 4.21 },
          rate:  { per: :kwh, rate: 0.020422 }
        }
      }
    },
  
  # =========Woodthorpe Primary School========
    9120550903 =>  {
      SHEFFIELDYPOCONTRACTDATES_2015_2020 => {
        name:  'Corona Sheffield YPO 5 year gas plan',
        rates:  {
          standing_charge:  { per: :day, rate: 4.4 },
          rate:  { per: :kwh, rate: 0.020422 }
        }
      }
    },
  
  # =========Wybourn Primary School========
    9297324003 =>  {
      SHEFFIELDYPOCONTRACTDATES_2015_2020 => {
        name:  'Corona Sheffield YPO 5 year gas plan',
        rates:  {
          standing_charge:  { per: :day, rate: 8.54 },
          rate:  { per: :kwh, rate: 0.020422 }
        }
      }
    },
  
  	8912670405 =>  {
      SHEFFIELDYPOCONTRACTDATES_2015_2020 => {
        name:  'Corona Sheffield YPO 5 year gas plan',
        rates:  {
          standing_charge:  { per: :day, rate: 1.44 },
          rate:  { per: :kwh, rate: 0.020422 }
        }
      }
    },
  
  # =========Whiteways Primary========
    2163409301 =>  {
      SHEFFIELDYPOCONTRACTDATES_2015_2020 => {
        name:  'Corona Sheffield YPO 5 year gas plan',
        rates:  {
          standing_charge:  { per: :day, rate: 7.03 },
          rate:  { per: :kwh, rate: 0.020422 }
        }
      }
    },
  
  # =========Ecclesall Primary (Previously named 'Infants')========
    2155853706 =>  {
      SHEFFIELDYPOCONTRACTDATES_2015_2020 => {
        name:  'Corona Sheffield YPO 5 year gas plan',
        rates:  {
          standing_charge:  { per: :day, rate: 4.24 },
          rate:  { per: :kwh, rate: 0.020422 }
        }
      }
    },
  
  # =========Hunters Bar Infants and Juniors========
    6511808 =>  {
      SHEFFIELDYPOCONTRACTDATES_2015_2020 => {
        name:  'Corona Sheffield YPO 5 year gas plan',
        rates:  {
          standing_charge:  { per: :day, rate: 2.19 },
          rate:  { per: :kwh, rate: 0.020422 }
        }
      }
    },
  
  	6511101 =>  {
      SHEFFIELDYPOCONTRACTDATES_2015_2020 => {
        name:  'Corona Sheffield YPO 5 year gas plan',
        rates:  {
          standing_charge:  { per: :day, rate: 4.76 },
          rate:  { per: :kwh, rate: 0.020422 }
        }
      }
    },
  
  	6512204 =>  {
      SHEFFIELDYPOCONTRACTDATES_2015_2020 => {
        name:  'Corona Sheffield YPO 5 year gas plan',
        rates:  {
          standing_charge:  { per: :day, rate: 1.25 },
          rate:  { per: :kwh, rate: 0.020422 }
        }
      }
    },
  
  	9334657704 =>  {
      SHEFFIELDYPOCONTRACTDATES_2015_2020 => {
        name:  'Corona Sheffield YPO 5 year gas plan',
        rates:  {
          standing_charge:  { per: :day, rate: 1.26 },
          rate:  { per: :kwh, rate: 0.020422 }
        }
      }
    },
  
  # =========Watercliffe Meadow Community Primary School========
    9209120604 =>  {
      SHEFFIELDYPOCONTRACTDATES_2015_2020 => {
        name:  'Corona Sheffield YPO 5 year gas plan',
        rates:  {
          standing_charge:  { per: :day, rate: 3.75 },
          rate:  { per: :kwh, rate: 0.020422 }
        }
      }
    },
  
  # =========Athelstan Primary School========
    2148244308 =>  {
      SHEFFIELDYPOCONTRACTDATES_2015_2020 => {
        name:  'Corona Sheffield YPO 5 year gas plan',
        rates:  {
          standing_charge:  { per: :day, rate: 7.4 },
          rate:  { per: :kwh, rate: 0.020422 }
        }
      }
    },
  
  # =========Ballifield Primary School========
    6508101 =>  {
      SHEFFIELDYPOCONTRACTDATES_2015_2020 => {
        name:  'Corona Sheffield YPO 5 year gas plan',
        rates:  {
          standing_charge:  { per: :day, rate: 7.15 },
          rate:  { per: :kwh, rate: 0.020422 }
        }
      }
    },
  
  # =========Lydgate Junior school========
    6396610 =>  {
      SHEFFIELDYPOCONTRACTDATES_2015_2020 => {
        name:  'Corona Sheffield YPO 5 year gas plan',
        rates:  {
          standing_charge:  { per: :day, rate: 5.3 },
          rate:  { per: :kwh, rate: 0.020422 }
        }
      }
    },
  
  # =========Arbourthorne Community Primary========
    9124298109 =>  {
      SHEFFIELDYPOCONTRACTDATES_2015_2020 => {
        name:  'Corona Sheffield YPO 5 year gas plan',
        rates:  {
          standing_charge:  { per: :day, rate: 10.63 },
          rate:  { per: :kwh, rate: 0.020422 }
        }
      }
    },
  
  # =========King Edwards Upper========
    6516504 =>  {
      SHEFFIELDYPOCONTRACTDATES_2015_2020 => {
        name:  'Corona Sheffield YPO 5 year gas plan',
        rates:  {
          standing_charge:  { per: :day, rate: 0.86 },
          rate:  { per: :kwh, rate: 0.020422 }
        }
      }
    },
  
  	6517203 =>  {
      SHEFFIELDYPOCONTRACTDATES_2015_2020 => {
        name:  'Corona Sheffield YPO 5 year gas plan',
        rates:  {
          standing_charge:  { per: :day, rate: 16.77 },
          rate:  { per: :kwh, rate: 0.020422 }
        }
      }
    },
  
  	9306413207 =>  {
      SHEFFIELDYPOCONTRACTDATES_2015_2020 => {
        name:  'Corona Sheffield YPO 5 year gas plan',
        rates:  {
          standing_charge:  { per: :day, rate: 1.56 },
          rate:  { per: :kwh, rate: 0.020422 }
        }
      }
    }
  }.freeze
  private_constant :METER_TARIFFS
end