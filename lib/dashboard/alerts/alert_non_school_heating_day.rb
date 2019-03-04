#======================== Heating on for too many non school days of year ==============
# bit of an overlap with the day-type type breakdown
require_relative 'alert_gas_model_base.rb'

# alerts for leaving the heating on for too long over winter holidays and weekends
class AlertHeatingOnNonSchoolDays < AlertGasModelBase
  def initialize(school)
    super(school, :heating_on_days)
  end

  def analyse_private(asof_date)
    calculate_model(asof_date)
    breakdown = heating_day_breakdown_current_year(asof_date)

    @analysis_report.add_book_mark_to_base_url('HeatingOnSchoolDays')

    @analysis_report.term = :longterm

    @analysis_report.summary  = 'The school has its heating for '
    @analysis_report.summary += non_school_days_heating.to_s
    @analysis_report.summary += ' weekend and holiday days each year which is '
    @analysis_report.summary += non_school_days_heating_adjective

    text = @analysis_report.summary + '.'
    kwh_saving = breakdown[:weekend_heating_on] + breakdown[:holiday_heating_on]
    if kwh_saving > 0
      text += ' Well managed schools typically turn their heating avoid turning their heating on over weekends and holidays.'
      text += ' If the school is only partially occupied during weekend and holiday it is often better'
      text += ' to use fan heaters rather than heating the whole school.'
      text += ' If your school followed this pattern it could save ' + FormatEnergyUnit.format(:kwh, kwh_saving)
      text += ' or ' + FormatEnergyUnit.format(:£, ConvertKwh.convert(:kwh, :£, :gas, kwh_saving)) + '.'
    end
    description1 = AlertDescriptionDetail.new(:text, text)
    @analysis_report.add_detail(description1)

    @analysis_report.rating = school_days_heating_rating_out_of_10
    @analysis_report.status = school_days_heating > 100 ? :poor : :good
  end
end