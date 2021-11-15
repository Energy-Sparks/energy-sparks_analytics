require_relative './advice_general.rb'
class AdviceElectricityAnnual < AdviceElectricityBase
end

# require_relative '../charting_and_reports/old_advice/dashboard_analysis_advice.rb'

# legacy energy analysis advice: provides text either side
# of the :group_by_week_electricity_versus_benchmark chart
class AdviceElectricityAnnualBenchmarkChart < DashboardChartAdviceBase
  def generate_advice
    @header_advice = AverageSchoolData.new.introduction_to_benchmark_and_exemplar_charts +
                     AverageSchoolData.new.benchmark_and_exemplar_rankings(@school)

    @footer_advice = AverageSchoolData.new.addendum_to_benchmark_and_exemplar_charts
  end
end
