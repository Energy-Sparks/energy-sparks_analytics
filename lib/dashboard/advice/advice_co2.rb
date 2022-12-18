require_relative '../charting_and_reports/old_advice/co2_advice.rb'
require_relative './advice_old_to_new_conversion.rb'


class AdviceCarbon < AdviceStructuredOldToNewConversion
  class OldCO2Intro < DashboardEnergyAdvice::CO2IntroductionAndBenchmark; end

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

  class CO2AdviceComponentBase < AdviceOldToNewConversion
    def tariff_has_changed_html(fuel_type)
      return '' unless tariff_has_changed?(fuel_type)
  
      %(
        <p>
          Be careful comparing changes in annual use on the charts
          where £ is selected for the y-axis as the tariff has changed
          over the period of the chart.
        </p>
      )
    end

    private
  
    def tariff_has_changed?(fuel_type)
      meter = @school.aggregate_meter((fuel_type))
      sd = meter.amr_data.start_date
      ed = meter.amr_data.end_date
      meter.meter_tariffs.meter_tariffs_differ_within_date_range?(sd, ed)
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
    # class CO2LongTerm < DashboardEnergyAdvice::CO2ElectricityCO2LongTerm; end
    class CO2LastYear < DashboardEnergyAdvice::CO2ElectricityCO2LastYear; end
    class KwhLastWeek < DashboardEnergyAdvice::CO2ElectricitykWhLastWeek; end
    class CO2LastWeek < DashboardEnergyAdvice::CO2ElectricityCO2LastWeek; end
    def initialize(school)
      super(school)
      @summary = 'Your school\'s electricity carbon emissions'
      
      @content_data = [
        { type: :text,  advice_class: KwhLongTerm, data: KwhLongTerm::LAST_FEW_YEARS_KWH_1 },
        { type: :chart, advice_class: KwhLongTerm, data: :electricity_longterm_trend_kwh_with_carbon_unmodified },
        { type: :text,  advice_class: KwhLongTerm, data: tariff_has_changed_html(:electricity) },
        { type: :text,  advice_class: KwhLongTerm, data: KwhLongTerm::SUGGEST_SWITCHING_YAXIS_UNITS },
        { type: :text,  advice_class: KwhLongTerm, data: KwhLongTerm::LAST_FEW_YEARS_CO2_QUESTION_2 },

        { type: :text,  advice_class: CO2LastYear, data: CO2LastYear::LAST_YEAR_CO2_1 },
        { type: :chart, advice_class: CO2LastYear, data: :electricity_co2_last_year_weekly_with_co2_intensity_unmodified },
        { type: :text,  advice_class: CO2LastYear, data: CO2LastYear::LAST_YEAR_CO2_QUESTIONS_2 },

        { type: :text,  advice_class: KwhLastWeek, data: KwhLastWeek::LAST_WEEK_KWH_4 },
        { type: :chart, advice_class: KwhLastWeek, data: :electricity_kwh_last_7_days_with_co2_intensity_unmodified },
        { type: :text,  advice_class: KwhLastWeek, data: KwhLastWeek::LAST_WEEK_KWH_QUESTIONS_5 },

        { type: :text,  advice_class: CO2LastWeek, data: CO2LastWeek::LAST_WEEK_CO2_1 },
        { type: :chart, advice_class: CO2LastWeek, data: :electricity_co2_last_7_days_with_co2_intensity_unmodified },
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
        { type: :text,  advice_class: GasCO2LongTerm, data: tariff_has_changed_html(:gas) },
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
    def initialize(school)
      super(school)
      @summary = 'Creating a plan to reduce your school\'s carbon emissions'
      @content_data = [
        { type: :text, advice_class: CO2Overall, data: CO2Overall::OVERALL_CO2_EMISSIONS_QUESTIONS_7 }
      ]
    end
  end
end
