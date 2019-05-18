# Chart Timescale Management - manages interactive manipulation of chart timescales
#
# - take an existing chart, and allows:
#   - 'move'      - move whole chart  1 time period               (forward or back)
#   - 'extend'    - extend time period of x-axis by 1 time period (forward or back)
#   - 'contract'  - contract time period of x-axis by 1 time period (forward or back)
#   - 'compare'   - compare with adjascent time period            (forward or back)
#
class ChartManagerTimescaleManipulation
  include Logging

  def initialize(type, original_chart_config, school)
    @type = type
    @original_chart_config = original_chart_config.freeze
    @school = school
    logger.info "Creating time shift manipulator of type #{type}"
  end

  def self.factory(type, original_chart_config, school)
    case type
    when :move;     ChartManagerTimescaleManipulationMove.new(:move, original_chart_config, school)
    when :extend;   ChartManagerTimescaleManipulationExtend.new(:extend, original_chart_config, school)
    when :contract; ChartManagerTimescaleManipulationContract.new(:contract, original_chart_config, school)
    when :compare;  ChartManagerTimescaleManipulationContract.new(:compare, original_chart_config, school)
    else
      raise EnergySparksUnexpectedStateException.new('Unexpected nil chart adjustment timescale shift') if type.nil?
      raise EnergySparksUnexpectedStateException.new("Unexpected chart adjustment timescale shift #{type}")
    end
  end

  def adjust_timescale(factor)
    new_config = @original_chart_config.deep_dup
    logger.info "Old timescales #{new_config[:timescale]}"

    available_periods = available_periods(new_config)
    logger.info "#{available_periods} periods available for chart time manipulation"

    timescales = convert_timescale_to_array(new_config)

    new_timescales = timescale_adjust(timescales, factor, available_periods)

    logger.info "New timescales #{new_timescales}"
    
    new_config[:timescale] = new_timescales

    new_config
  end

  protected

  def manipulate_timescale(timescale, factor, available_periods)
    raise EnergySparksAbstractBaseClass.new('attempt to call abstract base class for time manipulation')
  end

  def timescale_adjust(timescales, factor, available_periods)
    new_timescales = []
    timescales.each do |timescale|
      new_timescales.push(manipulate_timescale(timescale, factor, available_periods))
    end
    new_timescales
  end

  private

  def determine_chart_range(chart_config)
    aggregator = Aggregator.new(@school, chart_config)
    chart_config, _schools = aggregator.initialise_schools_date_range # get min and max combined meter ranges
    if chart_config.key?(:min_combined_school_date) || chart_config.key?(:max_combined_school_date)
      logger.info "METER range = #{chart_config[:min_combined_school_date]} to #{chart_config[:max_combined_school_date]}"
      [chart_config[:min_combined_school_date], chart_config[:max_combined_school_date]]
    else
      raise EnergySparksUnexpectedStateException.new('Unable to determine chart date range')
    end
  end

  def convert_timescale_to_array(chart_config)
    timescales = []
    timescale = chart_config[:timescale]
    if timescale.is_a?(Symbol)
      timescales = [ {timescale => 0}]
    elsif timescale.is_a?(Array)
      timescales = timescale
    else
      raise EnergySparksUnexpectedStateException.new("Unsupported timescale #{timescale} for chart manipulation")
    end
    timescales
  end

  def available_periods(chart_config_original)
    chart_range_first_possible_date, chart_range_last_possible_date = determine_chart_range(chart_config_original)
    timescale_type = timescale_type(chart_config_original)
    Holidays.periods_in_date_range(chart_range_first_possible_date, chart_range_last_possible_date, timescale_type, @school.holidays)
  end

  def timescale_type(chart_config_original)
    timescale = chart_config_original[:timescale]
    if timescale.is_a?(Symbol)
      timescale
    elsif timescale.is_a?(Array) && timescale[0].is_a?(Hash)
      key, _value = timescale[0].first
      key
    else
      raise EnergySparksUnexpectedStateException.new("Unsupported timescale type for chart timescale manipulation #{timescale}")
    end
  end

  def calculate_new_period_number(period_number, factor, available_periods)
    new_period_number = period_number + factor
    if new_period_number > 0 || new_period_number < (-1 * (available_periods - 1))
      raise EnergySparksUnexpectedStateException.new("Timescale charge request out of range #{new_period_number} versus #{available_periods} limit")
    end
    new_period_number
  end
end

class ChartManagerTimescaleManipulationMove < ChartManagerTimescaleManipulation
  def initialize(type, holidays, original_chart_config)
    super(type, holidays, original_chart_config)
  end

  def manipulate_timescale(timescale, factor, available_periods)
    period_type, period_number = timescale.first
    if period_number.is_a?(Integer)
      new_period_number = calculate_new_period_number(period_number, factor, available_periods)
      { period_type => new_period_number }
    elsif period_number.is_a?(Range)
      new_start_period_number = calculate_new_period_number(period_number.min, factor, available_periods)
      new_end_period_number = calculate_new_period_number(period_number.max, factor, available_periods)
      { period_type => Range.new(new_start_period_number, new_end_period_number) }
    else
      raise EnergySparksUnexpectedStateException.new("Unsupported period number #{period_number} type")
    end
  end
end

class ChartManagerTimescaleManipulationExtend < ChartManagerTimescaleManipulation
  def initialize(type, holidays, original_chart_config)
    super(type, holidays, original_chart_config)
  end

  def manipulate_timescale(timescale, factor, available_periods)
    period_type, period_number = timescale.first
    if period_number.is_a?(Integer)
      new_period_number = calculate_new_period_number(period_number, factor, available_periods)
      new_range = factor > 0 ? Range.new(period_number, new_period_number) : Range.new(new_period_number, period_number)
      {period_type => new_range}
    elsif period_number.is_a?(Range)
      new_range = nil
      if factor > 0
        new_end_period_number = calculate_new_period_number(period_number.max, factor, available_periods)
        new_range = Range.new(period_number.min, new_end_period_number)
      else
        new_start_period_number = calculate_new_period_number(period_number.min, factor, available_periods)
        new_range = Range.new(new_start_period_number, period_number.max)
      end
      {period_type => new_range}
    else
      raise EnergySparksUnexpectedStateException.new("Unsupported period number #{period_number} type")
    end
  end
end

class ChartManagerTimescaleManipulationContract < ChartManagerTimescaleManipulation
  def initialize(type, holidays, original_chart_config)
    super(type, holidays, original_chart_config)
  end

  def manipulate_timescale(timescale, factor, available_periods)
    period_type, period_number = timescale.first
    if period_number.is_a?(Integer)
      # do nothing as can't contract single time range, should potentially raise error
      {period_type => period_number}
    elsif period_number.is_a?(Range)
      new_range = nil
      if factor > 0
        new_end_period_number = calculate_new_period_number(period_number.max, -1 * factor, available_periods)
        new_range = Range.new(period_number.min, new_end_period_number)
      else
        new_start_period_number = calculate_new_period_number(period_number.min, -1 * factor, available_periods)
        new_range = Range.new(new_start_period_number, period_number.max)
      end
      if new_range.first == new_range.last
        if new_range.first == 0
          return period_type  # contract specification to just a Symbol e.g. :year
        else
          return {period_type => new_range.first} # contract Range to an Interger
        end
      else 
        {period_type => new_range}
      end
    else
      raise EnergySparksUnexpectedStateException.new("Unsupported period number #{period_number} type")
    end
  end
end

class ChartManagerTimescaleManipulationCompare < ChartManagerTimescaleManipulation
  def initialize(type, holidays, original_chart_config)
    super(type, holidays, original_chart_config)
  end

  def timescale_adjust(timescales, factor, available_periods)
    new_timescales = []
    timescale_comparison_to_extend = factor > 0 ? timescales.last : timescales.first
    additional_comparison = manipulate_timescale_compare(timescale_comparison_to_extend, factor, available_periods)
    if factor > 0
      new_timescales = timescales + additional_comparison
    else
      # new_timescales.push(additional_comparison)
      new_timescales << additional_comparison << timescales.flatten
    end
    new_timescales
  end

  def manipulate_timescale(timescale, factor, available_periods)
    period_type, period_number = timescale.first
    if period_number.is_a?(Integer)
      new_period_number = calculate_new_period_number(period_number, factor, available_periods)
      {period_type => new_period_number}
    elsif period_number.is_a?(Range)
      new_start_period_number = calculate_new_period_number(period_number.min, period_number.size * factor, available_periods)
      new_end_period_number = calculate_new_period_number(period_number.max, period_number.size * factor, available_periods)
      new_range = Range.new(new_start_period_number, new_end_period_number)
      {period_type => new_range}
    else
      raise EnergySparksUnexpectedStateException.new("Unsupported period number #{period_number} type")
    end
  end
end
