#======================== Heating on for too many school days of year ==============
require_relative 'alert_gas_model_base.rb'

# alerts for leaving the heating on for too long over winter
class AlertHeatingOnSchoolDays < AlertHeatingDaysBase
  def initialize(school)
    super(school, :heating_on_days)
  end

  def analyse_private(asof_date)
    calculate_model(asof_date)
    breakdown = heating_day_breakdown_current_year(asof_date)

    @analysis_report.add_book_mark_to_base_url('HeatingOnSchoolDays')

    @analysis_report.term = :longterm

    @analysis_report.summary  = 'The school has its heating for '
    @analysis_report.summary += school_days_heating.to_s
    @analysis_report.summary += ' school days each year which is '
    @analysis_report.summary += school_days_heating_adjective

    text = @analysis_report.summary + '.'
    kwh_saving = breakdown[:schoolday_heating_on_not_recommended]
    if kwh_saving > 0
      text += ' Well managed schools typically turn their heating on in late October and off in mid-April. '
      text += ' If your school followed this pattern it could save ' + FormatEnergyUnit.format(:kwh, kwh_saving)
      text += ' or ' + FormatEnergyUnit.format(:£, ConvertKwh.convert(:kwh, :£, :gas, kwh_saving)) + '.'
    end
    description1 = AlertDescriptionDetail.new(:text, text)
    @analysis_report.add_detail(description1)

    @analysis_report.rating = school_days_heating_rating_out_of_10
    @analysis_report.status = school_days_heating > 100 ? :poor : :good
  end
end