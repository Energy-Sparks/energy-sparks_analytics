# TODO(PH, 30Mar2022): reconsider implementation, whether derived from Struct, OpenStruct or Hash
class AggregatorConfig < OpenStruct
  def config_none_or_nil?(config_key)
    !key?(config_key) || self[config_key].nil? || self[config_key] == :none
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
