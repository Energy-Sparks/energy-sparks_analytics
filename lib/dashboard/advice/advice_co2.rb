require_relative '../charting_and_reports/co2_advice.rb'

module MeterlessMixin
  def enough_data;      :enough   end
  def rating;           5.0       end
  def relevance;        :relevant end
  def check_relevance;  relevance end
  def self.template_variables
    { 'Summary' => { summary: { description: 'CO2 data', units: String } } }
  end
end

class AdviceCarbon < AdviceBase
  include MeterlessMixin
  class OldCO2Intro < DashboardEnergyAdvice::CO2IntroductionAndBenchmark; end
  attr_reader :summary

  def has_structured_content?
    true
  end

  def component_pages
    [
      CO2IntroductionAdvice,
      CO2CarbonEmissionFactorsAdvice,
      CO2OverallGasAndElectricityAdvice,
      CO2ElectricityAdvice,
      CO2GasAdvice,
      CO2OverallAssessment,
      CO2Plan
    ]
  end

  def structured_content
    content_information = []
    component_pages.each do |component_page_class|
      component_page = component_page_class.new(@school)
      content_information.push(
        {
          title:    component_page.summary,
          content:  component_page.content
        }
      ) if component_page.relevance == :relevant
    end
    content_information
  end

  def content
    structured_content.map { |component| component[:content] }.flatten
  end

  def summary
    @summary ||= summary_text
  end

  def alert_asof_date
    [@school.aggregated_electricity_meters, @school.aggregated_heat_meters].compact.map { |meter| meter.amr_data.end_date }.min
  end

  def enough_data
    # TODO(PH, 16Jan2020) - temp comment out
    max_period_days > 364 ? :enough : :not_enough
  end

  private

  def min_data
    [@school.aggregated_electricity_meters, @school.aggregated_heat_meters].compact.map { |meter| meter.amr_data.start_date }.max
  end

  def max_period_days
    (alert_asof_date - min_data + 1).to_i
  end

  def timescale
    { up_to_a_year: 0 }
  end

  def timescale_description
    FormatEnergyUnit.format(:years, [max_period_days / 365.0, 1.0].min, :html)
  end

  def summary_text
    "Your school emitted #{total_co2_html} over the last #{timescale_description}, equivalent to planting #{trees_description}"
  end

  def total_co2
    annual_electricity_co2 + annual_gas_co2
  end

  def total_co2_html
    FormatEnergyUnit.format(:co2, total_co2, :html)
  end

  def trees_electricity
    @school.electricity? ? EnergyConversions.new(@school).front_end_convert(:tree_co2_tree, timescale, :allelectricity_unmodified)[:equivalence] : 0.0
  end

  def trees_gas
    @school.gas? ? EnergyConversions.new(@school).front_end_convert(:tree_co2_tree, timescale, :gas)[:equivalence] : 0.0
  end

  def trees_description
    trees = (trees_electricity + trees_gas).round(0).to_i
    "#{trees} trees"
  end

  def annual_electricity_co2
    @annual_electricity_co2 ||= @school.electricity? ? ScalarkWhCO2CostValues.new(@school).aggregate_value(timescale, :allelectricity_unmodified, :co2) : 0.0
  end

  def annual_gas_co2
    @annual_gas_co2 ||= @school.gas? ? ScalarkWhCO2CostValues.new(@school).aggregate_value(timescale, :gas, :co2) : 0.0
  end

  class CO2AdviceComponentBase < AdviceBase
    include MeterlessMixin
    def initialize(school)
      super(school)
      @content_data = []
      @content_list = []
    end

    def default_accordian_state; :closed end

    def content
      charts_and_html = []
      @content_list.each do |component|
        charts_and_html.push( { type: component[:type], content: component[:content] } )
      end
      @content_data.each do |content|
        begin
          advice_class = content[:advice_class].new(@school, nil, nil, nil)
          charts_and_html.push(
            case content[:type]
            when :text
              { type: :html,  content: advice_class.erb_bind(content[:data]) }
            when :function
              { type: :html,  content: advice_class.send(content[:data]) }
            when :chart
              { type: :chart, content: run_chart(content[:data]) }
            end
          )
        rescue EnergySparksNotEnoughDataException => e
          { type: :chart, html: 'Unfortunately we don\'t have enough meter data to provide this information.' }
        end
      end
      charts_and_html
    end
  end

  class CO2IntroductionAdvice < CO2AdviceComponentBase
    include MeterlessMixin
    def initialize(school)
      super(school)
      @summary = 'Introduction to school carbon emissions'
      @content_data = [
        { type: :text, advice_class: OldCO2Intro, data: OldCO2Intro::INTRO_TO_SCHOOL_CO2_1 },
        { type: :text, advice_class: OldCO2Intro, data: OldCO2Intro::INTRO_TO_SCHOOL_CO2_GAS_AND_ELECTRICITY_2 }
      ]
    end
  end

  class CO2CarbonEmissionFactorsAdvice < CO2AdviceComponentBase
    include MeterlessMixin
    def initialize(school)
      super(school)
      @summary = 'Carbon intensity, emission factors and sources of electricity'
      @content_data = [
        { type: :text,      advice_class: OldCO2Intro, data: OldCO2Intro::CARBON_EMISSION_FACTORS_3 },
        { type: :text,      advice_class: OldCO2Intro, data: OldCO2Intro::INTRO_TO_SCHOOL_CO2_GAS_AND_ELECTRICITY_2 },
        { type: :function,  advice_class: OldCO2Intro, data: :grid_carbon_intensity_live_html_table },
        { type: :text,      advice_class: OldCO2Intro, data: OldCO2Intro::COMPARISON_WITH_2018_ELECTRICITY_MIX }
      ]
    end
  end

  class CO2OverallGasAndElectricityAdvice < CO2AdviceComponentBase
    include MeterlessMixin
    def initialize(school)
      super(school)
      @summary = 'Your school\'s overall carbon emissions'
      @content_data = [
        { type: :text,  advice_class: OldCO2Intro, data: OldCO2Intro::SCHOOL_CARBON_EMISSIONS_OVER_LAST_FEW_YEARS_4 },
        { type: :chart, advice_class: OldCO2Intro, data: :benchmark_co2 },
        { type: :text,  advice_class: OldCO2Intro, data: OldCO2Intro::QUESIONS_CARBON_EMISSIONS_OVER_LAST_FEW_YEARS_5 }
      ]
    end
  end

  class CO2ElectricityAdvice < CO2AdviceComponentBase
    include MeterlessMixin
    class KwhLongTerm < DashboardEnergyAdvice::CO2ElectricityKwhLongTerm; end
    class CO2LongTerm < DashboardEnergyAdvice::CO2ElectricityCO2LongTerm; end
    class CO2LastYear < DashboardEnergyAdvice::CO2ElectricityCO2LastYear; end
    class KwhLastWeek < DashboardEnergyAdvice::CO2ElectricitykWhLastWeek; end
    class CO2LastWeek < DashboardEnergyAdvice::CO2ElectricityCO2LastWeek; end
    def initialize(school)
      super(school)
      @summary = 'Your school\'s electricity carbon emissions'
      @content_data = [
        { type: :text,  advice_class: KwhLongTerm, data: KwhLongTerm::LAST_FEW_YEARS_KWH_1 },
        { type: :chart, advice_class: KwhLongTerm, data: :electricity_longterm_trend_kwh_with_carbon_unmodified },

        { type: :text,  advice_class: CO2LongTerm, data: CO2LongTerm::LAST_FEW_YEARS_CO2_1 },
        { type: :chart, advice_class: CO2LongTerm, data: :electricity_longterm_trend_carbon_unmodified },
        { type: :text,  advice_class: CO2LongTerm, data: CO2LongTerm::LAST_FEW_YEARS_CO2_QUESTION_2 },

        { type: :text,  advice_class: CO2LastYear, data: CO2LastYear::LAST_YEAR_CO2_1 },
        { type: :chart, advice_class: CO2LastYear, data: :electricity_co2_last_year_weekly_with_co2_intensity_unmodified },
        { type: :text,  advice_class: CO2LastYear, data: CO2LastYear::LAST_YEAR_CO2_QUESTIONS_2 },

        { type: :text,  advice_class: KwhLastWeek, data: KwhLastWeek::LAST_WEEK_KWH_4 },
        { type: :chart, advice_class: KwhLastWeek, data: :electricity_kwh_last_7_days_with_co2_intensity_unmodified },
        { type: :text,  advice_class: KwhLastWeek, data: KwhLastWeek::LAST_WEEK_KWH_QUESTIONS_5 },

        { type: :text,  advice_class: CO2LastWeek, data: CO2LastWeek::LAST_WEEK_CO2_1 },
        { type: :chart, advice_class: CO2LastWeek, data: :electricity_kwh_last_7_days_with_co2_intensity_unmodified },
        { type: :text,  advice_class: CO2LastWeek, data: CO2LastWeek::LAST_WEEK_CO2_QUESTIONS_2 },
      ]
    end

    def relevance; @school.electricity? ? :relevant : :never_relevant end
  end

  class CO2GasAdvice < CO2AdviceComponentBase
    include MeterlessMixin
    class GasCO2LongTerm < DashboardEnergyAdvice::CO2GasCO2EmissionsLongTermTrends; end
    class GasCO2LastYear < DashboardEnergyAdvice::CO2GasCO2EmissionsLastYear; end 
    def initialize(school)
      super(school)
      @summary = 'Your school\'s gas carbon emissions'
      @content_data = [
        { type: :text,  advice_class: GasCO2LongTerm, data: '<h2>Your School\'s Gas Carbon Emissions over the last few years</h2>' },

        { type: :text,  advice_class: GasCO2LongTerm, data: GasCO2LongTerm::GAS_LONG_TERM_CO2_1 },
        { type: :chart, advice_class: GasCO2LongTerm, data: :gas_longterm_trend_kwh_with_carbon },
        { type: :text,  advice_class: GasCO2LongTerm, data: GasCO2LongTerm::GAS_LONG_TERM_CO2_QUESTIONS_2 },

        { type: :text,  advice_class: GasCO2LastYear, data: GasCO2LastYear::GAS_LAST_YEAR_CO2_1 },
        { type: :chart, advice_class: GasCO2LastYear, data: :group_by_week_carbon },
        { type: :text,  advice_class: GasCO2LastYear, data: GasCO2LastYear::GAS_LAST_YEAR_CO2_QUESTIONS_2 }
      ]
    end
    def relevance; @school.gas? ? :relevant : :never_relevant end
  end

  class CO2OverallAssessment < CO2AdviceComponentBase
    include MeterlessMixin
    class CO2Overall < DashboardEnergyAdvice::CO2GasCO2EmissionsLastYear; end
    def initialize(school)
      super(school)
      @summary = 'Assessing your school\'s overall carbon emissions (energy, transport, food)'
      @content_data = [
        { type: :text,  advice_class: CO2Overall, data: CO2Overall::OVERALL_CO2_EMISSIONS_1 },
        { type: :text,  advice_class: CO2Overall, data: CO2Overall::EMBEDDED_EXCEL_CARBON_CALCULATOR },
        { type: :text,  advice_class: CO2Overall, data: CO2Overall::OVERALL_CO2_EMISSIONS_2 },
        { type: :text,  advice_class: CO2Overall, data: CO2Overall::OVERALL_CO2_EMISSIONS_TRANSPORT_3 },
        { type: :text,  advice_class: CO2Overall, data: CO2Overall::OVERALL_CO2_EMISSIONS_FOOD_4 },
        { type: :text,  advice_class: CO2Overall, data: CO2Overall::OVERALL_CO2_EMISSIONS_ENERGY_5 },
        { type: :text,  advice_class: CO2Overall, data: CO2Overall::OVERALL_CO2_EMISSIONS_TOTAL_6 }
      ]
    end
  end
  
  class CO2Plan < CO2AdviceComponentBase
    include MeterlessMixin
    class CO2Overall < DashboardEnergyAdvice::CO2GasCO2EmissionsLastYear; end
    @summary = 'Creating a plan to reduce your school\'s carbon emissions'
    def initialize(school)
      super(school)
      @content_data = [
        { type: :text, advice_class: CO2Overall, data: CO2Overall::OVERALL_CO2_EMISSIONS_QUESTIONS_7 }
      ]
    end
  end
end
