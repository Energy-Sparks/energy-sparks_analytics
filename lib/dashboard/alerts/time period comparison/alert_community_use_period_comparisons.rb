require_relative './alert_schoolweek_comparison_electricity.rb'
require_relative './alert_schoolweek_comparison_gas.rb'
require_relative './alert_previous_holiday_comparison_electricity.rb'
require_relative './alert_previous_holiday_comparison_gas.rb'

module AlertCommunityUseMixin
  def initialize(school, type = class_type)
    super
    calculate_relevance
  end

  def calculate_relevance
    @relevance = (@relevance == :relevant && @school.community_usage?) ? :relevant : :never_relevant
  end

  protected def community_use
    { filter: :community_only, aggregate: :all_to_single_value }
  end

  private

  def class_type
    self.class.name.to_sym
  end
end
  
class AlertCommunitySchoolWeekComparisonElectricity < AlertSchoolWeekComparisonElectricity
  def adjusted_temperature_comparison_chart
    :schoolweek_alert_2_week_comparison_for_internal_calculation_adjusted_community_only
  end

  def unadjusted_temperature_comparison_chart
    :schoolweek_alert_2_week_comparison_for_internal_calculation_unadjusted_community_only
  end
end

class AlertCommunitySchoolWeekComparisonGas < AlertSchoolWeekComparisonGas
  include AlertCommunityUseMixin
end

class AlertCommunityPreviousHolidayComparisonGas < AlertPreviousHolidayComparisonGas
  include AlertPeriodComparisonTemperatureAdjustmentMixin
  include AlertCommunityUseMixin
end
