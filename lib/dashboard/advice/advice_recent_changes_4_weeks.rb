class AdviceRecentChangeBase < AdviceElectricityBase
  attr_reader :rating, :percentage_change, :difference_per_week_£
  attr_reader :prefix_1, :prefix_2, :summary

  def initialize(school, fuel_type)
    super(school)
    @fuel_type = fuel_type
  end

  def self.template_variables
    { 'Summary' => TEMPLATE_VARIABLES }
  end

  TEMPLATE_VARIABLES = {
    rating: {
      description: 'Rating out of 10',
      units:  Float
    },
    percentage_change: {
      description: 'percent change between last 4 weeks and previous 4 weeks',
      units:  :relative_perent
    },
    difference_per_week_£: {
      description: 'change in average weekly usage between last 4 weeks and previous 4 weeks',
      units:  :£
    },
    prefix_1: {
      description: 'Change: up or down',
      units: String
    },
    prefix_2: {
      description: 'Change: increase or reduction',
      units: String
    },
    summary: {
      description: 'Change in weekly £spend, relative to previous 4 weeks',
      units: String
    }
  }

  def calculate
    begin
      scalar = ScalarkWhCO2CostValues.new(@school)
      @last_4_school_weeks_£_per_week = scalar.aggregate_value({schoolweek: -3..0},  @fuel_type, :£) / 4.0
      @previous_4_school_weeks_£_per_week = scalar.aggregate_value({schoolweek: -7..-4}, @fuel_type, :£) / 4.0
      @difference_per_week_£ = @last_4_school_weeks_£_per_week - @previous_4_school_weeks_£_per_week
      @percentage_change = @difference_per_week_£ / @previous_4_school_weeks_£_per_week
      @rating = calculate_rating_from_range(-0.1, 0.1, @percentage_change)
      @prefix_1 = @difference_per_week_£ > 0 ? 'up' : 'down'
      @prefix_2 = @difference_per_week_£ > 0 ? 'increase' : 'reduction'
      @summary = summary_text
    rescue EnergySparksNotEnoughDataException => _e
      @rating = nil
      @summary = 'Not enough meter data, yet'
    end
  end

  def summary_text
    FormatEnergyUnit.format(:£, @difference_per_week_£, :text) + ' ' +
    @prefix_2 + ' in weekly consumption since 4 weeks ago, ' +
    '(' + FormatEnergyUnit.format(:relative_percent, @percentage_change, :text) + ')'
  end
end

class AdviceElectricityRecent < AdviceRecentChangeBase
  def initialize(school)
    super(school, :electricity)
  end
end

class AdviceGasRecent < AdviceRecentChangeBase
  def initialize(school)
    super(school, :gas)
  end
end
