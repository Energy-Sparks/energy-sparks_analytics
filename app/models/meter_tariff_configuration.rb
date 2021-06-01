# configuration information for meter tariff class
class MeterTariffs
  SHEFFIELDYPOCONTRACTDATES_2015_2020 = Date.new(2015, 1, 1)..Date.new(2020, 3, 1)
  BATHCONTRACTDATES_2008_2020 = Date.new(2008, 1, 1)..Date.new(2022, 3, 1)
  FROMECONTRACTDATES_2015_2020 = Date.new(2015, 1, 1)..Date.new(2022, 3, 1)
  HIGHLANDSCONTRACTDATES_2015_2020 = Date.new(2015, 1, 1)..Date.new(2022, 3, 1)
  SOMERSETCONTRACTDATES_2015_2020 = Date.new(2017, 1, 1)..Date.new(2022, 3, 1)
  FOREVERCONTRACTDATES = Date.new(2000, 1, 1)..Date.new(2050, 1, 1)
  # TODO(PH, 12Jun2019) update times to regional times : https://greennetworkenergy.co.uk/help-centre/meters-and-meter-reading/economy-7/
  ECONOMY7_NIGHT_TIME_PERIOD = TimeOfDay.new(0, 0)..TimeOfDay.new(6, 30)
  ECONOMY7_DAY_TIME_PERIOD = TimeOfDay.new(6, 30)..TimeOfDay.new(24, 0)
  DEFAULT_NIGHTTIME_RATE_FOR_DIFFERENTIAL_TARIFF = 0.08
  DEFAULT_DAYTIME_RATE_FOR_DIFFERENTIAL_TARIFF = 0.13
  DEFAULT_ELECTRICITY_ECONOMIC_TARIFF = 0.12
  DEFAULT_SOLAR_PV_TARIFF = 0.12
  DEFAULT_SOLAR_PV_EXPORT_TARIFF = 0.05
  BLENDED_DIFFERNTIAL_RATE_APPROX = (13 * DEFAULT_NIGHTTIME_RATE_FOR_DIFFERENTIAL_TARIFF + (48 - 13) * DEFAULT_DAYTIME_RATE_FOR_DIFFERENTIAL_TARIFF)/ 48.0

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
    site_fee: {
      summary:      'Site Fee',
      description:  'Site Fee'
    },
    other: {
      summary:      'Charge of type not in default list',
      description:  'Miscellaneous not in default list'
    }
  }.freeze

end
