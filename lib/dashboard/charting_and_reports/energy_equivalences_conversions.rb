require_relative 'format_energy_unit.rb'
class EnergyEquivalences
  def self.format_unit(value, unit)
    case unit
    when :£
      "£#{value}"
    when :kwh
      "#{value}kWh"
    when :co2
      "#{value}CO2 KG"
    else
      "#{value}#{unit.to_sym}"
    end
  end

  class X < FormatEnergyUnit # shorten name
  end

  J_TO_KWH = 1000.0 * 60 * 60

  UK_ELECTRIC_GRID_CO2_KG_KWH = 0.280
  UK_ELECTRIC_GRID_£_KWH = BenchmarkMetrics::ELECTRICITY_PRICE
  UK_DOMESTIC_ELECTRICITY_£_KWH = 0.15

  UK_GAS_CO2_KG_KWH = 0.210
  UK_GAS_£_KWH = BenchmarkMetrics::GAS_PRICE
  GAS_BOILER_EFFICIENCY = 0.7

  WATER_ENERGY_LITRE_PER_K_J = 4200
  WATER_ENERGY_KWH_LITRE_PER_K = WATER_ENERGY_LITRE_PER_K_J / J_TO_KWH
  WATER_ENERGY_DESCRIPTION = "It takes #{X.format(:kwh, WATER_ENERGY_KWH_LITRE_PER_K)} of energy to heat 1 litre of water by 1C. "

  ICE_LITRES_PER_100KM = 7.1
  LITRE_PETROL_KWH = 9.6
  LITRE_PETROL_CO2_KG = 2.31
  LITRE_PETROL_£ = 1.2
  ICE_KWH_KM = (LITRE_PETROL_KWH * ICE_LITRES_PER_100KM / 100.0).round(2)
  ICE_CO2_KM = (ICE_LITRES_PER_100KM * LITRE_PETROL_CO2_KG / 100.0).round(3)
  ICE_£_KM = (ICE_LITRES_PER_100KM * LITRE_PETROL_£ / 100.0).round(4)
  ICE_CAR_EFFICIENCY = "A petrol car uses #{X.format(:litre, ICE_LITRES_PER_100KM)} of fuel to travel 100 km (40 mpg). "
  ICE_DESCRIPTION_TO_KWH =\
        ICE_CAR_EFFICIENCY +
        "Each litre of petrol contains #{X.format(:kwh, LITRE_PETROL_KWH)} of energy, thus it takes "\
        "#{X.format(:litre, ICE_LITRES_PER_100KM)} &times; #{X.format(:kwh, LITRE_PETROL_KWH)}/l &divide; 100 km = "\
        "#{X.format(:kwh, ICE_KWH_KM)} for a car to travel 1 km. "
  ICE_DESCRIPTION_CO2_KG =\
        ICE_CAR_EFFICIENCY +
        "Each litre of petrol contains #{X.format(:co2, LITRE_PETROL_CO2_KG)}, thus the car emits "\
        "#{X.format(:litre, ICE_LITRES_PER_100KM)} &times; #{X.format(:kg, LITRE_PETROL_CO2_KG)}/l "\
        " &divide; 100 km = #{X.format(:co2, ICE_CO2_KM)} when it travels 1 km. "
  ICE_DESCRIPTION_TO_£ =\
        ICE_CAR_EFFICIENCY +
        "A litre of petrol costs about #{X.format(:£, LITRE_PETROL_£)} "\
        "so it costs #{X.format(:litre, ICE_LITRES_PER_100KM)} &times; #{X.format(:£, LITRE_PETROL_£)} &divide; 100km "\
        "= #{X.format(:£, ICE_£_KM)} to travel 1 km "\
        "(In reality if you include the costs of maintenance, servicing, depreciation "\
        "it can cost about £0.30/km to travel by car). "

  BEV_KWH_PER_KM = 64.0 / (239.0 * 1.6) # Hyundia Kona Electric goes 260 miles on
  BEV_CO2_PER_KM = BEV_KWH_PER_KM * UK_ELECTRIC_GRID_CO2_KG_KWH
  BEV_£_PER_KM = BEV_KWH_PER_KM * UK_DOMESTIC_ELECTRICITY_£_KWH
  BEV_EFFICIENCY_DESCRIPTION = "An electric car uses #{X.format(:kwh, BEV_KWH_PER_KM)} of electricity to travel 1 km. "
  BEV_CO2_DESCRIPTION = "An electric car emits #{X.format(:co2, BEV_CO2_PER_KM)} of electricity to travel 1 km (emissons from the National Grid). "

  SHOWER_TEMPERATURE_RAISE = 25.0
  SHOWER_LITRES = 50.0
  SHOWER_KWH_GROSS = (SHOWER_LITRES * SHOWER_TEMPERATURE_RAISE * WATER_ENERGY_LITRE_PER_K_J / J_TO_KWH).round(3)
  SHOWER_KWH_NET = (SHOWER_KWH_GROSS / GAS_BOILER_EFFICIENCY).round(3)
  SHOWER_£ = SHOWER_KWH_NET * UK_GAS_£_KWH
  SHOWER_CO2_KG = SHOWER_KWH_NET * UK_GAS_CO2_KG_KWH
  WATER_COST_PER_LITRE = 4.0 / 1000.0
  SHOWER_DESCRIPTION_TO_KWH =\
        "1 shower uses #{X.format(:litre, SHOWER_LITRES)} of water, which is heated from 15C to 40C (25C rise). " +
        WATER_ENERGY_DESCRIPTION +
        "It therefore takes #{X.format(:litre, SHOWER_LITRES)} &times; #{X.format(:kwh, WATER_ENERGY_KWH_LITRE_PER_K)} &times; " +
        "#{SHOWER_TEMPERATURE_RAISE} = #{X.format(:kwh, SHOWER_KWH_GROSS)} to heat 1 litre of water by 20C. " +
        "However gas boilers are only #{GAS_BOILER_EFFICIENCY * 100.0} &percnt; efficient, so " +
        "#{X.format(:kwh, SHOWER_KWH_GROSS)} &divide; #{GAS_BOILER_EFFICIENCY} " +
        "= #{X.format(:kwh, SHOWER_KWH_NET)} of gas is required. ".freeze

  UK_DOMESTIC_GAS_£_KWH = 0.05
  HOMES_ELECTRICITY_KWH_YEAR = 2_600
  HOMES_GAS_KWH_YEAR = 14_000
  HOMES_ELECTRICITY_CO2_YEAR = HOMES_ELECTRICITY_KWH_YEAR * UK_ELECTRIC_GRID_CO2_KG_KWH
  HOMES_GAS_CO2_YEAR = HOMES_GAS_KWH_YEAR * UK_GAS_CO2_KG_KWH
  HOMES_KWH_YEAR = HOMES_ELECTRICITY_KWH_YEAR + HOMES_GAS_KWH_YEAR
  HOMES_CO2_YEAR = HOMES_ELECTRICITY_CO2_YEAR + HOMES_GAS_CO2_YEAR
  HOMES_ELECTRICITY_£_YEAR = HOMES_ELECTRICITY_KWH_YEAR * UK_DOMESTIC_ELECTRICITY_£_KWH
  HOMES_GAS_£_YEAR = HOMES_GAS_KWH_YEAR * UK_DOMESTIC_GAS_£_KWH
  HOMES_£_YEAR = HOMES_ELECTRICITY_£_YEAR + HOMES_GAS_£_YEAR

  KETTLE_LITRE_BY_85C_KWH = (85.0 * WATER_ENERGY_KWH_LITRE_PER_K).round(3)
  KETTLE_LITRES = 1.5
  KETTLE_KWH = KETTLE_LITRES * KETTLE_LITRE_BY_85C_KWH
  KETTLE_£ = KETTLE_KWH * UK_ELECTRIC_GRID_£_KWH
  KETTLE_CO2_KG = KETTLE_KWH * UK_ELECTRIC_GRID_CO2_KG_KWH
  ONE_KETTLE_DESCRIPTION_TO_KWH =\
          WATER_ENERGY_DESCRIPTION +
          "It takes #{X.format(:kwh, WATER_ENERGY_KWH_LITRE_PER_K)} of energy to heat 1 litre of water by 1C. "\
          "A kettle contains about #{X.format(:litre, KETTLE_LITRES)} of water, which is heated by 85C from 15C to 100C. "\
          "Therefore it takes #{X.format(:litre, KETTLE_LITRES)} &times; 85C &times; #{X.format(:kwh, WATER_ENERGY_KWH_LITRE_PER_K)} "\
          "= #{X.format(:kwh, KETTLE_KWH)} of energy to boil 1 kettle. ".freeze

  SMARTPHONE_CHARGE_kWH = 3.6 * 2.0 / 1000.0 # 3.6V * 2.0 Ah / 1000
  SMARTPHONE_CHARGE_£ = SMARTPHONE_CHARGE_kWH * UK_ELECTRIC_GRID_£_KWH
  SMARTPHONE_CHARGE_CO2_KG = SMARTPHONE_CHARGE_kWH * UK_ELECTRIC_GRID_CO2_KG_KWH

  ONE_HOUR = 1.0
  TV_POWER_KW = 0.04 # also kWh/hour
  TV_HOUR_£ = TV_POWER_KW * ONE_HOUR * UK_ELECTRIC_GRID_£_KWH
  TV_HOUR_CO2_KG = TV_POWER_KW * ONE_HOUR * UK_ELECTRIC_GRID_CO2_KG_KWH

  TREE_LIFE_YEARS = 40
  TREE_CO2_KG_YEAR = 22
  TREE_CO2_KG = TREE_LIFE_YEARS * TREE_CO2_KG_YEAR # https://www.quora.com/How-many-trees-do-I-need-to-plant-to-offset-the-carbon-dioxide-released-in-a-flight

  LIBRARY_BOOK_£ = 5

  TEACHING_ASSISTANT_£_HOUR = 8.33

  CARNIVORE_DINNER_£ = 2.5
  CARNIVORE_DINNER_CO2_KG = 4.0
  VEGETARIAN_DINNER_£ = 1.5
  VEGETARIAN_DINNER_CO2_KG = 2.0

  ONSHORE_WIND_TURBINE_LOAD_FACTOR_PERCENT = 0.27
  ONSHORE_WIND_TURBINE_CAPACITY_KW = 500
  ONSHORE_WIND_TURBINE_AVERAGE_KW_PER_HOUR = ONSHORE_WIND_TURBINE_LOAD_FACTOR_PERCENT * ONSHORE_WIND_TURBINE_CAPACITY_KW * ONE_HOUR

  OFFSHORE_WIND_TURBINE_LOAD_FACTOR_PERCENT = 0.38
  OFFSHORE_WIND_TURBINE_CAPACITY_KW = 3000
  OFFSHORE_WIND_TURBINE_AVERAGE_KW_PER_HOUR = OFFSHORE_WIND_TURBINE_LOAD_FACTOR_PERCENT * OFFSHORE_WIND_TURBINE_CAPACITY_KW * ONE_HOUR

  SOLAR_PANEL_KWP = 300.0
  SOLAR_PANEL_YIELD_PER_KWH_PER_KWP_PER_YEAR = 0.83
  SOLAR_PANEL_KWH_PER_YEAR = SOLAR_PANEL_KWP * SOLAR_PANEL_YIELD_PER_KWH_PER_KWP_PER_YEAR

  ENERGY_EQUIVALENCES = {
    electricity: {
      description: '%s of electricity',
      conversions: {
        kwh:  {
          rate:         1.0,
          description:  ''
        },
        co2:  {
          rate:         UK_ELECTRIC_GRID_CO2_KG_KWH,
          description:  "In 2018 the UK electricity grid emitted #{X.format(:co2, UK_ELECTRIC_GRID_CO2_KG_KWH)} "\
                        "for every 1 kWh of electricity supplied. "
        },
        £:  {
          rate:         UK_ELECTRIC_GRID_£_KWH,
          description:  "Electricity costs schools about £#{UK_ELECTRIC_GRID_£_KWH} per kWh. "
        }
      }
    },
    gas: {
      description: '%s of gas',
      conversions: {
        kwh:  {
          rate:         1.0,
          description:  ''
        },
        co2:  {
          rate:         UK_GAS_CO2_KG_KWH,
          description:  "The carbon intensity of gas is #{UK_GAS_CO2_KG_KWH}kg/kWh. ",
        },
        £:  {
          rate:         UK_GAS_£_KWH,
          description:  "Gas costs schools about £#{UK_GAS_£_KWH} per kWh. ",
        }
      }
    },
    ice_car: {
      description: 'driving a petrol car %s',
      conversions: {
        kwh:  {
          rate:                   ICE_KWH_KM,
          description:            ICE_DESCRIPTION_TO_KWH,
          front_end_description:  'Distance (km) travelled by a petrol car (conversion using kwh)',
          calculation_variables:  {
            ice_kwh_per_km:        { value: ICE_KWH_KM,           units: :kwh_per_km,   description: 'kwh required to travel for 1km'}
          }
        },
        co2:  {
          rate:         ICE_CO2_KM,
          description:  ICE_DESCRIPTION_CO2_KG,
          front_end_description:  'Distance (km) travelled by a petrol car (conversion using co2)',
          calculation_variables:  {
            ice_co2_per_km:        { value: ICE_CO2_KM,           units: :co2_kg_per_km,description: 'kg co2 per 1km'}
          }
        },
        £:  {
          rate:         ICE_£_KM,
          description:  ICE_DESCRIPTION_TO_£,
          front_end_description:  'Distance (km) travelled by a petrol car (conversion using £)',
          calculation_variables:  {
            ice_£_per_km:          { value: ICE_£_KM,             units: :£_per_km,     description: 'cost £ for 1km'}
          }
        }
      },
      convert_to:       :km
    },
    bev_car: {
      description: 'driving a battery electric car %s',
      conversions: {
        kwh:  {
          rate:         BEV_KWH_PER_KM,
          description:  BEV_EFFICIENCY_DESCRIPTION,
          front_end_description:  'Distance (km) travelled by a battery electric car (conversion using kwh)',
          calculation_variables:         {
            ice_litres_per_100_km: { value: ICE_LITRES_PER_100KM, units: :l_per_100_km, description: 'litres petrol for 100km (~40mpg)'},
          }
        },
        co2:  {
          rate:         BEV_CO2_PER_KM,
          description:  BEV_CO2_DESCRIPTION,
          front_end_description:  'Distance (km) travelled by a battery electric car (conversion using co2)'
        },
        £:  {
          rate:         BEV_£_PER_KM,
          description:  BEV_EFFICIENCY_DESCRIPTION,
          front_end_description:  'Distance (km) travelled by a battery electric car (conversion using £)'
        }
      },
      convert_to:       :km
    },
    home: {
      description: 'the annual energy consumption of %s',
      conversions: {
        kwh:  {
          rate:         HOMES_KWH_YEAR,
          description:  "An average uk home uses #{X.format(:kwh, HOMES_ELECTRICITY_KWH_YEAR)} of electricity "\
                        "and #{X.format(:kwh, HOMES_GAS_KWH_YEAR)} of gas per year, "\
                        "so a total of #{X.format(:kwh, HOMES_KWH_YEAR)}. ",
          front_end_description:  'The consumption of N average homes (conversion via kWh)'
        },
        co2:  {
          rate:         HOMES_CO2_YEAR,
          description:  "An average uk home uses #{X.format(:kwh, HOMES_ELECTRICITY_KWH_YEAR)} of electricity "\
                        "and #{X.format(:kwh, HOMES_GAS_KWH_YEAR)} of gas per year. "\
                        "The carbon intensity of 1 kWh of electricity = #{X.format(:co2, UK_ELECTRIC_GRID_CO2_KG_KWH)}/kWh and "\
                        "gas #{X.format(:co2, UK_GAS_CO2_KG_KWH)}/kWh. "\
                        "Therefore 1 home emits #{X.format(:kwh, HOMES_ELECTRICITY_KWH_YEAR)} &times; #{X.format(:co2, UK_ELECTRIC_GRID_CO2_KG_KWH)} + "\
                        "#{X.format(:kwh, HOMES_GAS_KWH_YEAR)} &times; #{X.format(:co2, UK_GAS_CO2_KG_KWH)} = "\
                        "#{X.format(:co2, HOMES_CO2_YEAR)} per year. ",
          front_end_description:  'The consumption of N average homes (conversion via co2)'
        },
        £:  {
          rate:         HOMES_£_YEAR,
          description:  "An average uk home uses #{X.format(:kwh, HOMES_ELECTRICITY_KWH_YEAR)} of electricity "\
                        "and #{X.format(:kwh, HOMES_GAS_KWH_YEAR)} of gas per year. "\
                        "For homes the cost of 1 kWh of electricity = #{X.format(:£, UK_DOMESTIC_ELECTRICITY_£_KWH)}/kWh and "\
                        "gas #{X.format(:£, UK_DOMESTIC_GAS_£_KWH)}/kWh. "\
                        "Therefore 1 home costs #{X.format(:kwh, HOMES_ELECTRICITY_KWH_YEAR)} &times; #{X.format(:£, UK_DOMESTIC_ELECTRICITY_£_KWH)} + "\
                        "#{X.format(:kwh, HOMES_GAS_KWH_YEAR)} &times; #{X.format(:£, UK_DOMESTIC_GAS_£_KWH)} = "\
                        "#{X.format(:£, HOMES_£_YEAR)} in energy per year. ",
          front_end_description:  'The consumption of N average homes (conversion via £)'
        }
      },
      convert_to:             :home,
      equivalence_timescale:  :year,
      timescale_units:        :home
    },
    homes_electricity: {
      description: 'the annual electricity consumption of %s',
      conversions: {
        kwh:  {
          rate:         HOMES_ELECTRICITY_KWH_YEAR,
          description:  "A average uk home uses #{X.format(:kwh, HOMES_ELECTRICITY_KWH_YEAR)} of electricity ",
          front_end_description:  'The consumption of N average homes electricity (conversion via kWh)'
        },
        co2:  {
          rate:         HOMES_ELECTRICITY_CO2_YEAR,
          description:  "A average uk home uses #{X.format(:kwh, HOMES_ELECTRICITY_KWH_YEAR)} of electricity. "\
                        "The carbon intensity of 1 kWh of electricity = #{X.format(:co2, UK_ELECTRIC_GRID_CO2_KG_KWH)}/kWh. "\
                        "Therefore 1 home emits #{X.format(:kwh, HOMES_ELECTRICITY_KWH_YEAR)} &times; #{X.format(:co2, UK_ELECTRIC_GRID_CO2_KG_KWH)} = "\
                        "#{X.format(:co2, HOMES_ELECTRICITY_CO2_YEAR)} per year. ",
          front_end_description:  'The consumption of N average homes electricity (conversion via co2)'
        },
        £:  {
          rate:         HOMES_ELECTRICITY_£_YEAR,
          description:  "An average uk home uses #{X.format(:kwh, HOMES_ELECTRICITY_KWH_YEAR)} of electricity. "\
                        "For homes the cost of 1 kWh of electricity = #{X.format(:£, UK_DOMESTIC_ELECTRICITY_£_KWH)}/kWh. "\
                        "Therefore 1 home costs #{X.format(:kwh, HOMES_ELECTRICITY_KWH_YEAR)} &times; #{X.format(:£, UK_DOMESTIC_ELECTRICITY_£_KWH)} = "\
                        "#{X.format(:£, HOMES_ELECTRICITY_£_YEAR)} in electricity per year. ",
          front_end_description:  'The consumption of N average homes electricity (conversion via £)'
        }
      },
      convert_to:             :home,
      equivalence_timescale:  :year,
      timescale_units:        :home
    },
    homes_gas: {
      description: 'the annual gas consumption of %s',
      conversions: {
        kwh:  {
          rate:         HOMES_GAS_KWH_YEAR,
          description:  "A average uk home uses #{X.format(:kwh, HOMES_GAS_KWH_YEAR)} of gas ",
          front_end_description:  'The consumption of N average homes gas (conversion via kWh)'
        },
        co2:  {
          rate:         HOMES_GAS_CO2_YEAR,
          description:  "A average uk home uses #{X.format(:kwh, HOMES_GAS_KWH_YEAR)} of gas. "\
                        "The carbon intensity of 1 kWh of gas = #{X.format(:co2, UK_GAS_CO2_KG_KWH)}/kWh. "\
                        "Therefore 1 home emits #{X.format(:kwh, HOMES_GAS_KWH_YEAR)} &times; #{X.format(:co2, UK_GAS_CO2_KG_KWH)} = "\
                        "#{X.format(:co2, HOMES_GAS_CO2_YEAR)} per year. ",
          front_end_description:  'The consumption of N average homes gas (conversion via co2)'
        },
        £:  {
          rate:         HOMES_GAS_£_YEAR,
          description:  "An average uk home uses #{X.format(:kwh, HOMES_GAS_KWH_YEAR)} of gas. "\
                        "For homes the cost of 1 kWh of gas = #{X.format(:£, UK_DOMESTIC_GAS_£_KWH)}/kWh. "\
                        "Therefore 1 home costs #{X.format(:kwh, HOMES_GAS_KWH_YEAR)} &times; #{X.format(:£, UK_DOMESTIC_GAS_£_KWH)} = "\
                        "#{X.format(:£, HOMES_GAS_£_YEAR)} in gas per year. ",
          front_end_description:  'The consumption of N average homes gas (conversion via £)'
        }
      },
      convert_to:             :home,
      equivalence_timescale:  :year,
      timescale_units:        :home
    },
    shower: {
      description: 'taking %s',
      conversions: {
        kwh:  {
          rate:                   SHOWER_KWH_NET,
          description:            SHOWER_DESCRIPTION_TO_KWH,
          front_end_description:  'Number of showers (conversion via kWh)'
        },
        co2:  {
          rate:                   SHOWER_CO2_KG,
          description:            SHOWER_DESCRIPTION_TO_KWH +
                                  "Burning 1 kwh of gas (normal source of heat for showers) emits #{X.format(:kg, UK_GAS_CO2_KG_KWH)} CO2. "\
                                  "Therefore 1 shower uses #{X.format(:kg, SHOWER_CO2_KG)} CO2. ",
          front_end_description:  'Number of showers (conversion via co2)'
        },
        £:  {
          rate:         SHOWER_£,
          description:  SHOWER_DESCRIPTION_TO_KWH +
                        "1 kwh of gas costs #{X.format(:£, UK_GAS_£_KWH)}. "\
                        "Therefore 1 shower costs #{X.format(:kwh, SHOWER_KWH_NET)} &times; #{X.format(:£, UK_GAS_£_KWH)} = #{X.format(:£, SHOWER_£)} of gas. ",
          front_end_description:  'Number of showers (conversion via £)'
        }
      },
      convert_to:       :shower
    },
    kettle: {
      description: 'heating %s of water',
      conversions: {
        kwh:  {
          rate:         KETTLE_KWH,
          description:  ONE_KETTLE_DESCRIPTION_TO_KWH,
          front_end_description:  'Number of kettles boiled (conversion via kWh)'
        },
        co2:  {
          rate:         KETTLE_CO2_KG,
          description:  ONE_KETTLE_DESCRIPTION_TO_KWH +
                        "And, heating 1 kettle emits #{X.format(:kwh, KETTLE_KWH)} &times; #{X.format(:co2, UK_ELECTRIC_GRID_CO2_KG_KWH)}"\
                        " = #{X.format(:co2, KETTLE_CO2_KG)}. ",
          front_end_description:  'Number of kettles boiled (conversion via co2)'
        },
        £:  {
          rate:         KETTLE_£,
          description:  ONE_KETTLE_DESCRIPTION_TO_KWH +
                        "Thus it costs #{X.format(:£, UK_ELECTRIC_GRID_£_KWH)} &times; #{X.format(:kwh, KETTLE_KWH)} = "\
                        "#{X.format(:£, KETTLE_£)} to boil a kettle. ",
          front_end_description:  'Number of kettles boiled (conversion via £)'
        }
      },
      convert_to:       :kettle
    },
    smartphone: {
      description: '%s',
      conversions: {
        kwh:  {
          rate:                   SMARTPHONE_CHARGE_kWH,
          description:            "It takes #{X.format(:kwh, SMARTPHONE_CHARGE_kWH)} to charge a smartphone. ",
          front_end_description:  'Number of charges of a smartphone (conversion via kWh)'
        },
        co2:  {
          rate:                   SMARTPHONE_CHARGE_CO2_KG,
          description:            "It takes #{X.format(:kwh, SMARTPHONE_CHARGE_kWH)} to charge a smartphone. "\
                                  "Generating 1 kWh of electricity produces #{X.format(:co2, UK_ELECTRIC_GRID_£_KWH)}. "\
                                  "Therefore charging one smartphone produces #{X.format(:co2, SMARTPHONE_CHARGE_CO2_KG)}. ",
          front_end_description:  'Number of charges of a smartphone (conversion via co2)'
        },
        £:  {
          rate:                   SMARTPHONE_CHARGE_£,
          description:            "It takes #{X.format(:kwh, SMARTPHONE_CHARGE_kWH)} to charge a smartphone. "\
                                  "Generating 1 kWh of electricity costs #{X.format(:£, UK_ELECTRIC_GRID_£_KWH)}. "\
                                  "Therefore charging one smartphone costs #{X.format(:£, SMARTPHONE_CHARGE_£)}. ",
          front_end_description:  'Number of charges of a smartphone (conversion via co2)'
        }
      },
      convert_to:       :smartphone
    },
    tv: {
      description: '%s',
      conversions: {
        kwh:  {
          rate:                   TV_POWER_KW,
          description:            "TVs use about #{X.format(:kwh, TV_POWER_KW)} of electricity every hour. ",
          front_end_description:  'Number of hours of TV usage (converted via kWh)'
        },
        co2:  {
          rate:                   TV_HOUR_CO2_KG,
          description:            "TVs use about #{X.format(:kwh, TV_POWER_KW)} of electricity every hour. "\
                                  "Generating 1 kWh of electricity produces #{X.format(:co2, UK_ELECTRIC_GRID_£_KWH)}. "\
                                  "Therefore using a TV for 1 hour produces #{X.format(:co2, TV_HOUR_CO2_KG)}. ",
          front_end_description:  'Number of hours of TV usage (converted via co2)'
        },
        £:  {
          rate:         TV_HOUR_£,
          description:  "TVs use about #{X.format(:kwh, TV_POWER_KW)} of electricity every hour. "\
                        "Generating 1 kWh of electricity costs #{X.format(:£, UK_ELECTRIC_GRID_£_KWH)}. "\
                        "Therefore using a TV for 1 hour costs #{X.format(:£, TV_HOUR_£)}. ",
          front_end_description:  'Number of hours of TV usage (converted via £)'
        }
      },
      convert_to:             :hour,
      equivalence_timescale:  :hour,
      timescale_units:        :tv
    },
    tree: {
      description: 'planting a %s (40 year life)',
      conversions: {
        co2:  {
          rate:                   TREE_CO2_KG,
          description:            "An average tree absorbs #{X.format(:co2, TREE_CO2_KG_YEAR)} per year. "\
                                  "And if the tree lives to #{TREE_LIFE_YEARS} years it will absorb "\
                                  "#{X.format(:co2, TREE_CO2_KG)}. ",
          front_end_description:  'Number of trees (40 year life, CO2 conversion)'
        }
      },
      convert_to:       :tree
    },
    library_books: {
      description: 'the cost of %s',
      conversions: {
        £:  {
          rate:                   LIBRARY_BOOK_£,
          description:            "A libary book costs about #{X.format(:£, LIBRARY_BOOK_£)}.",
          front_end_description:  'Number of library books (£5)'
        }
      },
      convert_to:       :library_books
    },
    teaching_assistant: {
      description: '%s',
      conversions: {
        £:  {
          rate:         TEACHING_ASSISTANT_£_HOUR,
          description:  "A school teaching assistant is paid on average #{X.format(:£, TEACHING_ASSISTANT_£_HOUR)} per hour.",
          front_end_description:  'Number of teaching assistant hours (£8.33/hour)'
        }
      },
      convert_to:             :teaching_assistant_hours,
      equivalence_timescale:  :working_hours,
      timescale_units:        :teaching_assistant
    },
    carnivore_dinner: {
      description: '%s',
      conversions: {
        co2:  {
          rate:                   CARNIVORE_DINNER_CO2_KG,
          description:            "#{X.format(:co2, CARNIVORE_DINNER_CO2_KG)} of CO2 is emitted producing one dinner containing meat.",
          front_end_description:  'Number of meals containing meat (conversion via co2, 4kg/meal)'
        },
        £:  {
          rate:                   CARNIVORE_DINNER_£,
          description:            "One dinner containing meat costs #{X.format(:£, CARNIVORE_DINNER_£)}.",
          front_end_description:  'Number of meals containing meat (conversion via £, £2.50/meal)'
        }
      },
      convert_to:       :carnivore_dinner
    },
    vegetarian_dinner: {
      description: '%s',
      conversions: {
        co2:  {
          rate:                     VEGETARIAN_DINNER_CO2_KG,
          description:              "#{X.format(:co2, VEGETARIAN_DINNER_CO2_KG)} of CO2 is emitted producing one vegetarian dinner.",
          front_end_description:    'Number of vegetarian meals (conversion via co2, 2kg/meal)'
        },
        £:  {
          rate:                     VEGETARIAN_DINNER_£,
          description:              "One vegetarian dinner costs #{X.format(:£, VEGETARIAN_DINNER_£)}.",
          front_end_description:    'Number of vegetarian meals (conversion via £, £1.50/meal)'
        }
      },
      convert_to:       :vegetarian_dinner
    },
    onshore_wind_turbine_hours: {
      description: '%s',
      conversions: {
        kwh:  {
          rate:         ONSHORE_WIND_TURBINE_AVERAGE_KW_PER_HOUR,
          description:  "An average onshore wind turbine has a maximum capacity of #{X.format(:kw, ONSHORE_WIND_TURBINE_CAPACITY_KW)}. "\
                        "On average (wind varies) it is windy enough to use #{X.format(:percent, ONSHORE_WIND_TURBINE_LOAD_FACTOR_PERCENT)} of that capacity. "\
                        "Therefore an average onshore wind turbine generates about #{X.format(:kwh, ONSHORE_WIND_TURBINE_AVERAGE_KW_PER_HOUR)} per hour.",
          front_end_description:    'Number of onshore wind turbine hours (converted using kWh)'
        }
      },
      convert_to:       :onshore_wind_turbine_hours,
      equivalence_timescale:  :hour,
      timescale_units:        :onshore_wind_turbines
    },
    offshore_wind_turbine_hours: {
      description: '%s',
      conversions: {
        kwh:  {
          rate:         OFFSHORE_WIND_TURBINE_AVERAGE_KW_PER_HOUR,
          description:  "An average onshore wind turbine has a maximum capacity of #{X.format(:kw, OFFSHORE_WIND_TURBINE_CAPACITY_KW)}. "\
                        "On average (wind varies) it is windy enough to use #{X.format(:percent, OFFSHORE_WIND_TURBINE_LOAD_FACTOR_PERCENT)} of that capacity. "\
                        "Therefore an average onshore wind turbine generates about #{X.format(:kwh, OFFSHORE_WIND_TURBINE_AVERAGE_KW_PER_HOUR)} per hour.",
          front_end_description:    'Number of offshore wind turbine hours (converted using kWh)'
        }
      },
      convert_to:       :offshore_wind_turbine_hours,
      equivalence_timescale:  :hour,
      timescale_units:        :offshore_wind_turbines
    },
    solar_panels_in_a_year: {
      description: '%s',
      conversions: {
        kwh:  {
          rate:         SOLAR_PANEL_KWH_PER_YEAR,
          description:  "An average solar panel produces #{X.format(:kwh, SOLAR_PANEL_KWH_PER_YEAR)} per year. ",
          front_end_description:    'Number of solar panels in a year (converted using kWh)'
        }
      },
      convert_to:             :solar_panels_in_a_year,
      equivalence_timescale:  :year,
      timescale_units:        :solar_panels
    },
  }.freeze
end
