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
        "#{X.format(:litre, ICE_LITRES_PER_100KM)} * #{X.format(:kwh, LITRE_PETROL_KWH)}/l / 100 km = "\
        "#{X.format(:kwh, ICE_KWH_KM)} for a car to travel 1 km"
  ICE_DESCRIPTION_CO2_KG =\
        ICE_CAR_EFFICIENCY +
        "Each litre of petrol contains #{X.format(:co2, LITRE_PETROL_CO2_KG)}, thus the car emits "\
        "#{X.format(:litre, ICE_LITRES_PER_100KM)} * #{X.format(:kg, LITRE_PETROL_CO2_KG)}/l "\
        " / 100 km = #{X.format(:co2, ICE_CO2_KM)} when it travels 1 km. "
  ICE_DESCRIPTION_TO_£ =\
        ICE_CAR_EFFICIENCY +
        "A litre of petrol costs about #{X.format(:£, LITRE_PETROL_£)}"
        "so it costs #{X.format(:litre, ICE_LITRES_PER_100KM)} * #{X.format(:£, LITRE_PETROL_£)} / 100km "\
        "= #{X.format(:£, ICE_£_KM)} to travel 1 km "\
        "(In reality if you include the costs of maintenance, servicing, depreciation "\
        "it can cost about £0.30/km to travel by car)"

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
        "It therefore takes #{X.format(:litre, SHOWER_LITRES)} * #{X.format(:kwh, WATER_ENERGY_KWH_LITRE_PER_K)} * " +
        "#{SHOWER_TEMPERATURE_RAISE} = #{X.format(:kwh, SHOWER_KWH_GROSS)} to heat 1 litre of water by 20C. " +
        "However gas boilers are only #{GAS_BOILER_EFFICIENCY * 100.0}percent efficient, so " +
        "#{X.format(:kwh, SHOWER_KWH_GROSS)} / #{GAS_BOILER_EFFICIENCY} " +
        "= #{X.format(:kwh, SHOWER_KWH_NET)} of gas is required. ".freeze

  UK_DOMESTIC_GAS_£_KWH = 0.05
  UK_DOMESTIC_ELECTRICITY_£_KWH = 0.15
  HOMES_ELECTRICITY_KWH_YEAR = 2_600
  HOMES_GAS_KWH_YEAR = 14_000
  HOMES_KWH_YEAR = HOMES_ELECTRICITY_KWH_YEAR + HOMES_GAS_KWH_YEAR
  HOMES_CO2_YEAR = HOMES_ELECTRICITY_KWH_YEAR * UK_ELECTRIC_GRID_CO2_KG_KWH + HOMES_GAS_KWH_YEAR * UK_GAS_CO2_KG_KWH
  HOMES_£_YEAR = HOMES_ELECTRICITY_KWH_YEAR * UK_DOMESTIC_ELECTRICITY_£_KWH + HOMES_GAS_KWH_YEAR * UK_DOMESTIC_GAS_£_KWH

  KETTLE_LITRE_BY_85C_KWH = (85.0 * WATER_ENERGY_KWH_LITRE_PER_K).round(3)
  KETTLE_LITRES = 1.5
  KETTLE_KWH = KETTLE_LITRES * KETTLE_LITRE_BY_85C_KWH
  KETTLE_£ = KETTLE_KWH * UK_ELECTRIC_GRID_£_KWH
  KETTLE_CO2_KG = KETTLE_KWH * UK_ELECTRIC_GRID_CO2_KG_KWH
  ONE_KETTLE_DESCRIPTION_TO_KWH =\
  WATER_ENERGY_DECRIPTION = WATER_ENERGY_DESCRIPTION +
          "It takes #{X.format(:kwh, WATER_ENERGY_KWH_LITRE_PER_K)} of energy to heat 1 litre of water by 1C. "\
          "A kettle contains about #{X.format(:litre, KETTLE_LITRES)} of water, which is heated by 85C from 15C to 100C. "\
          "Therefore it takes #{X.format(:litre, KETTLE_LITRES)} * 85C * #{X.format(:kwh, WATER_ENERGY_KWH_LITRE_PER_K)} "\
          "= #{X.format(:kwh, KETTLE_KWH)} of energy to boil 1 kettle. ".freeze

  SMARTPHONE_CHARGE_kWH = 3.6 * 2.0 / 1000.0 # 3.6V * 2.0 Ah / 1000
  SMARTPHONE_CHARGE_£ = SMARTPHONE_CHARGE_kWH * UK_ELECTRIC_GRID_£_KWH
  SMARTPHONE_CHARGE_CO2_KG = SMARTPHONE_CHARGE_kWH * UK_ELECTRIC_GRID_CO2_KG_KWH

  TREE_LIFE_YEARS = 40
  TREE_CO2_KG_YEAR = 22
  TREE_CO2_KG = TREE_LIFE_YEARS * TREE_CO2_KG_YEAR # https://www.quora.com/How-many-trees-do-I-need-to-plant-to-offset-the-carbon-dioxide-released-in-a-flight

  LIBRARY_BOOK_£ = 5

  TEACHING_ASSISTANT_£_HOUR = 8.33

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
                        "for every 1 kWh of electricity supplied."
        },
        £:  {
          rate:         UK_ELECTRIC_GRID_£_KWH,
          description:  "Electricity costs schools about £#{UK_ELECTRIC_GRID_£_KWH} per kWh."
        }
      }
    },
    gas: {
      description: '%s of gas',
      conversions: {
        kwh:  {
          rate:         1.0,
          description:  '',
        },
        co2:  {
          rate:         UK_GAS_CO2_KG_KWH,
          description:  "The carbon intensity gas is #{UK_GAS_CO2_KG_KWH}kg/kWh",
        },
        £:  {
          rate:         UK_GAS_£_KWH,
          description:  "Gas costs schools about £#{UK_GAS_£_KWH} per kWh",
        }
      }
    },
    ice_car: {
      description: 'driving a petrol car %s',
      conversions: {
        kwh:  {
          rate:         ICE_KWH_KM,
          description:  ICE_DESCRIPTION_TO_KWH
        },
        co2:  {
          rate:         ICE_CO2_KM,
          description:  ICE_DESCRIPTION_CO2_KG
        },
        £:  {
          rate:         ICE_£_KM,
          description:  ICE_DESCRIPTION_TO_£
        }
      }
    },
    home: {
      description: 'the annual energy consumption of %s',
      conversions: {
        kwh:  {
          rate:         HOMES_KWH_YEAR,
          description:  "A average uk home uses #{X.format(:kwh, HOMES_ELECTRICITY_KWH_YEAR)} of electricity "\
                        "and #{X.format(:kwh, HOMES_GAS_KWH_YEAR)} of gas per year. "\
                        "so a total of #{X.format(:kwh, HOMES_KWH_YEAR)}"
        },
        co2:  {
          rate:         HOMES_CO2_YEAR,
          description:  "A average uk home uses #{X.format(:kwh, HOMES_ELECTRICITY_KWH_YEAR)} of electricity "\
                        "and #{X.format(:kwh, HOMES_GAS_KWH_YEAR)} of gas per year. "\
                        "The carbon intensity of 1 kWh of electricity = #{X.format(:co2, UK_ELECTRIC_GRID_CO2_KG_KWH)}/kWh and "\
                        "gas #{X.format(:co2, UK_GAS_CO2_KG_KWH)} / kWh. "\
                        "Therefore 1 home emits #{X.format(:kwh, HOMES_ELECTRICITY_KWH_YEAR)} * #{X.format(:co2, UK_ELECTRIC_GRID_CO2_KG_KWH)} + "\
                        "#{X.format(:kwh, HOMES_GAS_KWH_YEAR)} * #{X.format(:co2, UK_GAS_CO2_KG_KWH)} = "\
                        "#{X.format(:co2, HOMES_CO2_YEAR)} per year."
        },
        £:  {
          rate:         HOMES_£_YEAR,
          description:  "An average uk home uses #{X.format(:kwh, HOMES_ELECTRICITY_KWH_YEAR)} of electricity "\
                        "and #{X.format(:kwh, HOMES_GAS_KWH_YEAR)} of gas per year. "\
                        "For homes the cost of 1 kWh of electricity = #{X.format(:£, UK_DOMESTIC_ELECTRICITY_£_KWH)}/kWh and "\
                        "gas #{X.format(:£, UK_DOMESTIC_GAS_£_KWH)}/kWh. "\
                        "Therefore 1 home costs #{X.format(:kwh, HOMES_ELECTRICITY_KWH_YEAR)} * #{X.format(:£, UK_DOMESTIC_ELECTRICITY_£_KWH)} + "\
                        "#{X.format(:kwh, HOMES_GAS_KWH_YEAR)} * #{X.format(:£, UK_DOMESTIC_GAS_£_KWH)} = "\
                        "#{X.format(:£, HOMES_£_YEAR)} in energy per year"
        }
      }
    },
    shower: {
      description: 'taking %s',
      conversions: {
        kwh:  {
          rate:         SHOWER_KWH_NET,
          description:  SHOWER_DESCRIPTION_TO_KWH
        },
        co2:  {
          rate:         SHOWER_CO2_KG,
          description:  SHOWER_DESCRIPTION_TO_KWH +
                        "Burning 1 kwh of gas (normal source of heat for showers) emits #{X.format(:kg, UK_GAS_CO2_KG_KWH)} CO2. "\
                        "Therefore 1 shower uses #{X.format(:kg, SHOWER_CO2_KG)} CO2."
        },
        £:  {
          rate:         SHOWER_£,
          description:  SHOWER_DESCRIPTION_TO_KWH +
                        "1 kwh of gas costs #{X.format(:£, UK_GAS_£_KWH)}. "\
                        "Therefore 1 shower costs #{X.format(:kwh, SHOWER_KWH_NET)} * #{X.format(:£, UK_GAS_£_KWH)} = #{X.format(:£, SHOWER_£)} of gas"
        }
      }
    },
    kettle: {
      description: 'heating %s of water',
      conversions: {
        kwh:  {
          rate:         KETTLE_KWH,
          description:  ONE_KETTLE_DESCRIPTION_TO_KWH
        },
        co2:  {
          rate:         KETTLE_CO2_KG,
          description:  ONE_KETTLE_DESCRIPTION_TO_KWH +
                        "And, heating 1 kettle emits #{X.format(:kwh, KETTLE_KWH)} * #{X.format(:co2, UK_ELECTRIC_GRID_CO2_KG_KWH)}"\
                        " = #{X.format(:co2, KETTLE_CO2_KG)}."
        },
        £:  {
          rate:         KETTLE_£,
          description:  ONE_KETTLE_DESCRIPTION_TO_KWH +
                        "Thus it costs #{X.format(:£, UK_ELECTRIC_GRID_£_KWH)} * #{X.format(:kwh, KETTLE_KWH)} = "\
                        "#{X.format(:£, KETTLE_£)} to boil a kettle"
        }
      }
    },
    smartphone: {
      description: '%s',
      conversions: {
        kwh:  {
          rate:         SMARTPHONE_CHARGE_kWH,
          description:  "It takes #{X.format(:kwh, SMARTPHONE_CHARGE_kWH)} to charge a smartphone. "
        },
        co2:  {
          rate:         SMARTPHONE_CHARGE_CO2_KG,
          description:  "It takes #{X.format(:kwh, SMARTPHONE_CHARGE_kWH)} to charge a smartphone. "\
                        "Generating 1 kWh of electricity produces #{X.format(:co2, UK_ELECTRIC_GRID_£_KWH)}. "\
                        "Therefore charging one smartphone produces #{X.format(:co2, SMARTPHONE_CHARGE_CO2_KG)}"
        },
        £:  {
          rate:         SMARTPHONE_CHARGE_£,
          description:  "It takes #{X.format(:kwh, SMARTPHONE_CHARGE_kWH)} to charge a smartphone. "\
                        "Generating 1 kWh of electricity costs #{X.format(:£, UK_ELECTRIC_GRID_£_KWH)}. "\
                        "Therefore charging one smartphone costs #{X.format(:£, SMARTPHONE_CHARGE_£)}"
        }
      }
    },
    tree: {
      description: 'planting a %s (40 year life)',
      conversions: {
        co2:  {
          rate:         TREE_CO2_KG,
          description:  "An average tree absorbs #{X.format(:co2, TREE_CO2_KG_YEAR)} per year. "\
                        "And if the tree lives to #{TREE_LIFE_YEARS} years it will absorb "\
                        "#{X.format(:co2, TREE_CO2_KG)}"
        }
      }
    },
    library_books: {
      description: 'the cost of %s',
      conversions: {
        £:  {
          rate:         LIBRARY_BOOK_£,
          description:  "A libary book costs about #{X.format(:£, LIBRARY_BOOK_£)}."\
        }
      }
    },
    teaching_assistant: {
      description: '%s',
      conversions: {
        £:  {
          rate:         TEACHING_ASSISTANT_£_HOUR,
          description:  "A school teaching assistant is paid on average #{X.format(:£, TEACHING_ASSISTANT_£_HOUR)} per hour."\
        }
      }
    },
  }.freeze
end
