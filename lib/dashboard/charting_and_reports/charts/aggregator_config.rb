# TODO(PH, 30Mar2022): reconsider implementation, whether derived from Struct, OpenStruct or Hash
class AggregatorConfig < OpenStruct
  def config_none_or_nil?(config_key)
    !key?(config_key) || self[config_key].nil? || self[config_key] == :none
  end

  def include_benchmark?
    !config_none_or_nil?(:benchmark)
  end

  def benchmark_calculation_types
    dig(:benchmark, :calculation_types)
  end

  def benchmark_override(school_name)
    return {} if dig(:benchmark, :calculation_types).nil? || dig(:benchmark, :config).nil?

    calc_types = dig(:benchmark, :calculation_types).map(&:to_s)

    return {} unless calc_types.include?(school_name)

    dig(:benchmark, :config)
  end

  def temperature_compensation_hash?
    adjust_by_temperature? &&
    dig(:adjust_by_temperature).is_a?(Hash) &&
    !key?(:temperature_adjustment_map)
  end

  def adjust_by_temperature?
    !dig(:adjust_by_temperature).nil?
  end

  def include_target?
    !config_none_or_nil?(:target)
  end

  def target_calculation_type
    dig(:target, :calculation_type)
  end

  def extend_chart_into_future?
    dig(:target, :extend_chart_into_future) == true
  end

  def sort_by?
    !sort_by.nil?
  end

  def sort_by
    dig(:sort_by)
  end

  def show_only_target_school?
    dig(:target, :show_target_only) == true
  end

  def timescale?
    !timescale.nil?
  end

  def timescale
    dig(:timescale)
  end

  def array_of_timescales?
    timescale? && timescale.is_a?(Array)
  end

  def add_daycount_to_legend?
    flag_is_true?(:add_day_count_to_legend)
  end

  def heating_daytype_filter?
    has_filter?(:heating_daytype)
  end

  def daytype_filter?
    has_filter?(:daytype)
  end

  def day_type_filter
    dig(:filter, :daytype)
  end

  def heating_filter?
    has_filter?(:heating)
  end

  def heating_filter
    dig(:filter, :heating)
  end

  def model_type_filter?
    has_filter?(:model_type)
  end

  def model_type_filters
    dig(:filter, :model_type)
  end

  def submeter_filter?
    has_filter?(:submeter)
  end

  def 
    heating_daytype
  end

  def chart_has_filter?
    !config_none_or_nil?(:filter)
  end

  # TODO)PH, 30Mar2022) make key private once SeriesDataManager has been upgraded to use new interfaces
  # slow? - is there a better way of doing this?
  def key?(k)
    to_h.key?(k)
  end

  private

  def flag_is_true?(k)
    key?(k) && send(k)
  end

  def has_filter?(type)
    chart_has_filter? && filter.key?(type) && !filter[type].nil?
  end
end
