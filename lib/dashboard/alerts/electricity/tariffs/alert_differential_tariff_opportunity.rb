#======================== Differential tariff change opportinity ===========================
require_relative '../alert_electricity_only_base.rb'

class AlertDifferentialTariffOpportunity < AlertElectricityOnlyBase
  MINIMUM_ANNUAL_SAVING_BEFORE_MAKING_RECOMMENDATION_£ = 100.0
  attr_reader :total_potential_savings_£, :total_potential_savings_percent
  attr_reader :differential_tariff_opportunity_table

  def initialize(school)
    super(school, :differential_cost_opportunity)
  end

  def self.template_variables
    specific = {'Differential Tariff' => TEMPLATE_VARIABLES}
    specific.merge(self.superclass.template_variables)
  end

  protected def format(unit, value, format, in_table, level)
    FormatUnit.format(unit, value, format, true, in_table, unit == :£ ? :no_decimals : level)
  end

  def timescale
    I18n.t("#{i18n_prefix}.timescale")
  end

  def enough_data
    days_amr_data >= 364 ? :enough : :not_enough
  end

  TEMPLATE_VARIABLES = {
    total_potential_savings_£: {
      description: 'Total percentage savings if meter tariffs changes as per recommendations (£)',
      units:  :£,
      benchmark_code: 'sav£'
    },
    total_potential_savings_percent: {
      description: 'Total percentage savings if meter tariffs changes as per recommendations (% of total consumption of those meters)',
      units:  :percent
    },
    differential_tariff_opportunity_table: {
      description: 'Potential opportunity to switch to/from a differential tariff for each electricity meter in a school',
      units: :table,
      header: ['MPAN', 'Cost Estimate Differential Tariff(year)', 'Cost Estimate Non-Differential Tariff(year)',
              'Saving(year)', 'Current Tariff', 'Recommendation'],
      column_types: [Integer, :£, :£, :£, String, String]
    },
  }

  protected def live_meters
    return @live_meters unless @live_meters.nil?
    max_combined_date = aggregate_meter.amr_data.end_date
    if @school.storage_heaters?
      @live_meters = []
      @school.electricity_meters.each do |electric_meter|
        if electric_meter.storage_heater?
          @live_meters.push(electric_meter.sub_meters[:mains_consume])
        elsif electric_meter.amr_data.end_date >= max_combined_date
          @live_meters.push(electric_meter)
        end
      end
    else
      @live_meters = @school.electricity_meters.select { |meter| meter.amr_data.end_date >= max_combined_date }
    end
    @live_meters
  end

  private def calculate(asof_date)
    # @annual_cost_with_differential_tariff_£, @annual_cost_without_differential_tariff_£ = calculate_differential_and_non_differential_costs(aggregate_meter, asof_date)

    saving_info_by_meter, @total_potential_savings_£, @total_potential_savings_percent = analyse_all_meters(asof_date)
    table = switching_advice_table_analytics_only(saving_info_by_meter)

    @differential_tariff_opportunity_table, _total_saving = calculate_differential_tariff_opportunity_table(saving_info_by_meter)

    assign_commmon_saving_variables(one_year_saving_£: @total_potential_savings_£, one_year_saving_co2: 0.0)

    @rating = calculate_rating_from_range(100.0, 1000.0, @total_potential_savings_£)
  end
  alias_method :analyse_private, :calculate

  private def analyse_all_meters(asof_date)
    meter_costs = {}
    total_saving_per_meter_£ = 0.0
    non_differential_cost_£_per_year = 0.0
    total_meters_consumption_for_meters_where_savings_possible_£ = 0.0

    live_meters.each do |electric_meter|
      differential_cost_£_per_year, non_differential_cost_£_per_year = calculate_differential_and_non_differential_costs(electric_meter, asof_date)
      on_differential_tariff = electric_meter.meter_tariffs.any_differential_tariff?(asof_date, asof_date - 1)
      sign_of_saving = on_differential_tariff ? 1 : -1
      saving_£_per_year = sign_of_saving * (differential_cost_£_per_year - non_differential_cost_£_per_year)
      if saving_£_per_year > 0.0
        total_saving_per_meter_£ += saving_£_per_year
        total_meters_consumption_for_meters_where_savings_possible_£ += non_differential_cost_£_per_year
      end

      meter_costs[electric_meter.mpan_mprn] = {
        differential_cost_£_per_year:     differential_cost_£_per_year,
        non_differential_cost_£_per_year: non_differential_cost_£_per_year,
        saving_£_per_year:                saving_£_per_year > 1.0 ? saving_£_per_year : 0.0,
        differential_tariff:              on_differential_tariff,
        percent_saving:                   saving_£_per_year / non_differential_cost_£_per_year
      }
    end
    total_saving_per_meter_£ = 0.0 if total_saving_per_meter_£ < 10.0 # loose floating point noise
    percent = non_differential_cost_£_per_year == 0.0 ? 0.0 : total_saving_per_meter_£ / total_meters_consumption_for_meters_where_savings_possible_£
    percent = 0.0 if percent.nan?
    [meter_costs, total_saving_per_meter_£, percent]
  end

  private def switching_advice_table_analytics_only(saving_info_by_meter)
    header = ['MPAN', 'Cost Estimate Differential Tariff(year)', 'Cost Estimate Non-Differential Tariff(year)', 'Saving(year)', 'Differential Tariff']

    total_saving = 0.0
    rows = []
    saving_info_by_meter.each do |mpan, info|
      total_saving += info[:saving_£_per_year] if info[:saving_£_per_year] > 0.0
      rows.push(
        [
          mpan,
          FormatEnergyUnit.format(:£, info[:differential_cost_£_per_year]),
          FormatEnergyUnit.format(:£, info[:non_differential_cost_£_per_year]),
          FormatEnergyUnit.format(:£, info[:saving_£_per_year]),
          info[:differential_tariff] ? 'yes' : 'no'
        ]
      )
    end

    total_saving = 0.0 if total_saving < 1.0 # remove floating point noise

    totals = ['', '', '', FormatEnergyUnit.format(:£, total_saving), '']
    need_totals = saving_info_by_meter.length == 1 || total_saving == 0.0

    [header, rows, need_totals ? nil : totals]
  end

  private def calculate_differential_tariff_opportunity_table(saving_info_by_meter)
    total_saving = 0.0
    rows = []
    saving_info_by_meter.each do |mpan, info|
      total_saving += info[:saving_£_per_year] if info[:saving_£_per_year] > 0.0
      recommendation = ''
      if info[:saving_£_per_year] > MINIMUM_ANNUAL_SAVING_BEFORE_MAKING_RECOMMENDATION_£
        opposite_tariff = info[:differential_tariff] ? 'non-differential' : 'differential'
        recommendation = 'consider changing tariff to a ' + opposite_tariff + ' tariff'
      end
      rows.push(
        [
          mpan,
          info[:differential_cost_£_per_year],
          info[:non_differential_cost_£_per_year],
          info[:saving_£_per_year],
          info[:differential_tariff] ? 'differential' : 'non-differential',
          recommendation
        ]
      )
    end
    [rows, total_saving]
  end

  private def latest_economic_tariff_rates(meter, date)
    meter.meter_tariffs.economic_tariff.tariff_on_date(date)
  end

  private def calculate_differential_and_non_differential_costs(meter, asof_date)
    total_daytime_cost = 0.0

    tariff = latest_economic_tariff_rates(meter, asof_date)
    flat_rate      = tariff[:rate]
    daytime_rate   = tariff[:daytime_rate]
    nighttime_rate = tariff[:nighttime_rate]

    total_differential_daytime_cost = 0.0
    differential_daytime_period = daytime_rate[:from]..daytime_rate[:to]
    differential_daytime_rates_x48 = DateTimeHelper.weighted_x48_vector_single_range(differential_daytime_period, daytime_rate[:rate])

    total_differential_nighttime_cost = 0.0
    nighttime_period = nighttime_rate[:from]..nighttime_rate[:to]
    nighttime_rates_x48 = DateTimeHelper.weighted_x48_vector_single_range(nighttime_period, nighttime_rate[:rate])

    start_date = meter_date_one_year_before(meter, asof_date)

    (start_date..asof_date).each do |date|
      kwh_x48 = meter.amr_data.days_kwh_x48(date)
      total_differential_nighttime_cost += AMRData.fast_multiply_x48_x_x48(kwh_x48, nighttime_rates_x48).sum
      total_differential_daytime_cost += AMRData.fast_multiply_x48_x_x48(kwh_x48, differential_daytime_rates_x48).sum
      total_daytime_cost += meter.amr_data.one_day_kwh(date) * flat_rate[:rate]
    end
    total_differential_tariff_cost = total_differential_daytime_cost + total_differential_nighttime_cost

    scale_factor = scale_up_to_one_year(meter, asof_date) # scale up to a year if < 1 year data

    [total_differential_tariff_cost * scale_factor, total_daytime_cost * scale_factor]
  end
end
