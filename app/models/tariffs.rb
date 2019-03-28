# maintains fuel pricing tariffs
class Tariffs
  attr_reader    :name

  def self.tariff_factory(type)
    case type
    when :economic_electricity_standard, :economic_electricity_gas
      Tariffs.new(type, ECONOMICTARIFFS[type])
    end
  end

  ECONOMICTARIFFS = {
    economic_electricity_standard:  { type: :flat, rates: 0.12, fuel_type: :electricity },
    economic_electricity_gas:       { type: :flat, rates: 0.03, fuel_type: :gas }
  }.freeze


  # school.tariff = bath_standard
  # or
  # school.tariff = { # school joined half way through programme
  #   Date.new(2009, 1, 1)..Date.new(2014, 1, 1) = {
  #        name:   'EON bargain basement economy 7 04',
  #        type:   :timeofday,
  #        rates:  {
  #            TimeOfDay.new(0,  0)..TimeOfDay.new(5, 30) => 0.08,
  #            TimeOfDay.new(5, 30)..TimeOfDay.new(24, 00) => 0.13
  #        },
  #        standing_charge:  0.50
  #    }
  #    Date.new(2014, 1, 2)..Date.new(2050, 1, 1) = :bath_standard
  #
  ACCOUNTINGTARIFFS = {
    bath_standard:  {
      electricity:  {
        Date.new(2009, 1, 1)..Date.new(2015, 1, 1) => {
          name:   'EON bargain basement economy 7 04',
          type:   :timeofday,
          rates:  {
            TimeOfDay.new(0,  0)..TimeOfDay.new(5, 30) => 0.08,
            TimeOfDay.new(5, 30)..TimeOfDay.new(24, 00) => 0.13
          },
          standing_charge:  0.50
        },
        Date.new(2015, 1, 1)..Date.new(2025, 1, 1) => {
          name:   'British Gas super saver 04',
          type:   :flat,
          rates:  0.15,
          standing_charge:  0.50
        }
      }
    }
  }

  attr_reader :fuel_type, :type
  def initialize(name, configuration)
    parse_configuration(configuration)
  end

  def tariff_day(date)
    @rate
  end

  def tariff_day_x48(date)
    Array.new(48, @rate)
  end

  def tariff_time(date, halfhour_index)
    @rate
  end

  private def parse_configuration(configuration)
    @rate      = configuration[:rates]
    @fuel_type = configuration[:fuel_type]
    @type      = configuration[:type]
  end
end
