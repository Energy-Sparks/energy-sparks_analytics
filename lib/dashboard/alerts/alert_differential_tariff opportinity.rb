#======================== Differential tariff change opportinity ===========================
require_relative 'alert_electricity_only_base.rb'

class AlertDifferentialTariffOpportunity < AlertElectricityOnlyBase
  NIGHTTIME_RATE_£_PER_KWH = 0.08
  DAYTIME_RATE_£_PER_KWH = 0.12
  DIFFERENTIAL_DAYTIME_RATE_£_PER_KWH = 0.13
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

  def timescale
    'year'
  end

  def enough_data
    days_amr_data >= 364 ? :enough : :not_enough
  end

  TEMPLATE_VARIABLES = {
    total_potential_savings_£: {
      description: 'Total percentage savings if meter tariffs changes as per recommendations (£)',
      units:  :£
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

  def one_year_saving_£
    @one_year_saving_£
  end

  def ten_year_saving_£
    super
  end

  protected def live_meters
    return @live_meters unless @live_meters.nil?
    max_combined_date = aggregate_meter.amr_data.end_date
    if @school.storage_heaters?
      @live_meters = []
      @school.electricity_meters.each do |electric_meter|
        if electric_meter.storage_heater?
          @live_meters += electric_meter.sub_meters.select { |meter| meter.amr_data.end_date >= max_combined_date && meter.fuel_type == :electricity }
        elsif electric_meter.amr_data.end_date >= max_combined_date
          @live_meters += electric_meter
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
    puts table

    @differential_tariff_opportunity_table, _total_saving = calculate_differential_tariff_opportunity_table(saving_info_by_meter)

    @one_year_saving_£ = Range.new(@total_potential_savings_£, @total_potential_savings_£)
    @rating = calculate_rating_from_range(100.0, 1000.0, @total_potential_savings_£)
  end

  private def analyse_all_meters(asof_date)
    meter_costs = {}
    total_saving_per_meter_£ = 0.0
    non_differential_cost_£_per_year = 0.0
    total_meters_consumption_for_meters_where_savings_possible_£ = 0.0

    live_meters.each do |electric_meter|
      differential_cost_£_per_year, non_differential_cost_£_per_year = calculate_differential_and_non_differential_costs(electric_meter, asof_date)
      on_differential_tariff = MeterTariffs.differential_tariff_in_date_range?(electric_meter.mpan_mprn, asof_date, asof_date - 1)
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

  private def calculate_differential_and_non_differential_costs(meter, asof_date)
    total_daytime_cost = 0.0

    total_differential_daytime_cost = 0.0
    differential_daytime_period = TimeOfDay.new(6, 30)..TimeOfDay.new(24, 0)
    differential_daytime_rates_x48 = DateTimeHelper.weighted_x48_vector_single_range(differential_daytime_period, DIFFERENTIAL_DAYTIME_RATE_£_PER_KWH)

    total_differential_nighttime_cost = 0.0
    nighttime_period = TimeOfDay.new(0, 0)..TimeOfDay.new(6, 30)
    nighttime_rates_x48 = DateTimeHelper.weighted_x48_vector_single_range(nighttime_period, NIGHTTIME_RATE_£_PER_KWH)

    start_date = meter_date_one_year_before(meter, asof_date)

    (start_date..asof_date).each do |date|
      kwh_x48 = meter.amr_data.days_kwh_x48(date)
      total_differential_nighttime_cost += AMRData.fast_multiply_x48_x_x48(kwh_x48, nighttime_rates_x48).sum
      total_differential_daytime_cost += AMRData.fast_multiply_x48_x_x48(kwh_x48, differential_daytime_rates_x48).sum
      total_daytime_cost += meter.amr_data.one_day_kwh(date) * DAYTIME_RATE_£_PER_KWH
    end
    total_differential_tariff_cost = total_differential_daytime_cost + total_differential_nighttime_cost

    scale_factor = scale_up_to_one_year(meter, asof_date) # scale up to a year if < 1 year data

    [total_differential_tariff_cost * scale_factor, total_daytime_cost * scale_factor]
  end

  def analyse_private(asof_date)
    calculate(asof_date)

    # temporary dummy text to maintain backwards compatibility
    @analysis_report.term = :longterm
    @analysis_report.summary, text =
      if @rating < 10
        [
          %q( There might be an opportunity to save costs by switching between a non-differential and differential (economy 7) tariff ),
          %q( 
            <p>
              Differential or economy 7 tariffs, charge less for electricity between midnight and 6:30am (8p/kWh),
              and slightly more for the rest of the day (13p/kWh), compared with normal tariffs which charge
              the same rate all day (12p/kWh). If you have a relatively high overnight usage, for example if
              you have storage heaters a differential tariff might reduce your electricity costs.
            </p>
            <p>
              Energy Sparks looks at your daytime and nightime usage and works out using approximate
              tariffs (13p/12p/8p) whether it might be beneficial for your school to switch to a differential
              tariff, or from a non-differential tariff, and
              presents these calculations for each of your electricity meters below.
            </p>
            <p>
              If Energy Sparks recommends that it might be beneficial to switch between differential tariff
              types you should get in contact with your supplier and ask for them to accurately estimate
              the cost benefits of switching. Given you have a smart or advanced meter providing half hourly
              meter readings, you shouldn't need a new meter.
            </p>
            <p>
              In total Energy Sparks estimates you could save <%= FormatEnergyUnit.format(:£, total_potential_savings_£) %>
              or <%= FormatEnergyUnit.format(:percent, total_potential_savings_percent) %> of your annual electricity bill
              by switching the meter(s) below. However, this doesnt include any additional standing charge you might have
              to pay, which you will need to ask your supplier about.
            </p>
            ).gsub(/^  /, '')
          ]
      else
        [
          %q( There are probably no opportunities for switching tariffs. ),
          ''
        ]
      end

    description1 = AlertDescriptionDetail.new(:text, ERB.new(text).result(binding))
    @analysis_report.add_detail(description1)
    @analysis_report.rating = 10.0
    @analysis_report.status = :good
  end
end
