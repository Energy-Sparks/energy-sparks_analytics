#======================== ASC Limit ===========================
require_relative 'alert_electricity_only_base.rb'

class AlertMeterASCLimit < AlertElectricityOnlyBase
  SAVING_PER_1_KW_ASC_LIMIT_REDUCTION_£_PER_YEAR = 1000.0 / 100.0
  ASC_MARGIN_PERCENT = 0.1
  attr_reader :maximum_kw_meter_period_kw, :asc_limit_kw
  attr_reader :text_explaining_asc_meters_below_limit, :number_of_meters_wording

  def initialize(school)
    super(school, :asclimit)
    # should really use asof date but not available in constructor
    if @relevance == :relevant
      opportunities = all_agreed_supply_capacities_with_peak_kw(Date.today)
      @relevance = opportunities.empty? ? :never_relevant : :relevant
    end
  end

  def self.template_variables
    specific = {'ASC Supply Limit' => TEMPLATE_VARIABLES}
    specific.merge(self.superclass.template_variables)
  end

  def timescale
    'year'
  end

  def enough_data
    :enough
  end

  def maximum_alert_date
    Date.today
  end

  TEMPLATE_VARIABLES = {
    maximum_kw_meter_period_kw: {
      description: 'Peak kW usage over period for which meter data available (potentially aggregate of multiple meters)',
      units:  :kw
    },
    asc_limit_kw: {
      description: 'Agreed Supply Capacity (ASC) limit total (potentially aggregate of multiple metersmultiple meters)',
      units:  :kw
    },
    text_explaining_asc_meters_below_limit: {
      description: 'Text explaining ASC meters within limit (potentially multiple meters)',
      units:  String
    },
    peak_kw_chart: {
      description: 'Chart showing daily peak kW over time, critical to observe maximum kW value, compared with ASC limit',
      units: :chart
    }
  }

  protected def format(unit, value, format, in_table, level)
    FormatUnit.format(unit, value, format, true, in_table, unit == :£ ? :no_decimals : level)
  end

  def peak_kw_chart
    :peak_kw
  end

  def one_year_saving_£
    @one_year_saving_£
  end

  def ten_year_saving_£
    super
  end

  def cost_of_consolidating_1_meter_£
    COST_OF_1_METER_CONSOLIDATION_£
  end

  protected def number_of_live_meters
    live_meters.length
  end

  protected def live_meters
    max_combined_date = aggregate_meter.amr_data.end_date
    @live_meters ||= @school.electricity_meters.select { |meter| meter.amr_data.end_date >= max_combined_date }
  end

  private def calculate(asof_date)
    opportunities = all_agreed_supply_capacities_with_peak_kw(asof_date)
    unless opportunities.empty?
      @text_explaining_asc_meters_below_limit = text_for_all_meters(opportunities)
      @asc_limit_kw = aggregate_asc_limit_kw(opportunities)
      @maximum_kw_meter_period_kw = aggregate_peak_kw(opportunities)
      annual_saving_£ = aggregate_annual_saving_£(opportunities)
      @one_year_saving_£ = Range.new(annual_saving_£, annual_saving_£)
      @rating = calculate_rating_from_range(400.0, 3000.0, annual_saving_£)
    else
      @rating = 10.0
    end
  end

  private def potential_annual_saving_£(peak_kw, asc_limit_kw)
    peak_plus_margin_kw = peak_kw * (1.0 + ASC_MARGIN_PERCENT)
    (asc_limit_kw - peak_kw) * SAVING_PER_1_KW_ASC_LIMIT_REDUCTION_£_PER_YEAR
  end

  private def close_to_margin(peak_kw, asc_limit_kw)
    peak_kw * (1.0 + ASC_MARGIN_PERCENT) > asc_limit_kw
  end

  private def agreed_supply_capacity(meter, date)
    asc = MeterTariffs.accounting_tariff_for_date(date, meter.mpan_mprn)
    asc.nil? ? nil : asc[:asc_limit_kw]
  end

  private def text_for_all_meters(opportunity_list)
    text = ''
    opportunity_list.each do |mpan, asc_info|
      text += text_for_one_meter(mpan, asc_info)
    end
    text
  end

  private def text_for_one_meter(mpan, asc_info)
    "For meter #{mpan} your ASC limit is #{FormatEnergyUnit.format(:kw, asc_info[:asc_limit_kw])} "\
    "but your peak power consumption is #{FormatEnergyUnit.format(:kw, asc_info[:peak_kw])}. " +
    text_for_opportunity_or_risk(asc_info)
  end

  private def text_for_opportunity_or_risk(asc_info)
    if asc_info[:close_to_margin]
      return 'You are very close to the agreed capacity limit, exceeding the list might result in a monthly penalty.'
    else
      return "There is an opportunity to save #{FormatEnergyUnit.format(:£, asc_info[:annual_saving_£])} per year, "\
             "or #{FormatEnergyUnit.format(:£, asc_info[:annual_saving_£] * 10.0)} if considered over a 10 year period. "
    end
  end

  private def all_agreed_supply_capacities_with_peak_kw(date)
    mpan_to_asc = {}
    live_meters.each do |meter|
      mpan_to_asc[meter.mpan_mprn] = agreed_supply_capacity(meter, date)
    end
    meters_with_asc_limits = mpan_to_asc.compact

    meters_with_limits_and_peak_values = {}
    meters_with_asc_limits.each do |mpan, asc_limit_kw|
      peak_kw = @school.meter?(mpan).amr_data.peak_kw_date_range_with_dates.values[0]
      meters_with_limits_and_peak_values[mpan] = {
        asc_limit_kw:     asc_limit_kw,
        peak_kw:          peak_kw,
        annual_saving_£:  potential_annual_saving_£(peak_kw, asc_limit_kw),
        close_to_margin:  close_to_margin(peak_kw, asc_limit_kw)
      }
    end
    meters_with_limits_and_peak_values
  end

  private def aggregate_asc_limit_kw(meters_with_limits_and_peak_values)
    meters_with_limits_and_peak_values.values.map { |info| info[:asc_limit_kw] }.sum
  end

  private def aggregate_peak_kw(meters_with_limits_and_peak_values)
    meters_with_limits_and_peak_values.values.map { |info| info[:peak_kw] }.sum
  end

  private def aggregate_annual_saving_£(meters_with_limits_and_peak_values)
    meters_with_limits_and_peak_values.values.map { |info| info[:annual_saving_£] }.sum
  end

  def analyse_private(asof_date)
    calculate(asof_date)

    # temporary dummy text to maintain backwards compatibility
    @analysis_report.term = :longterm
    @analysis_report.summary, text =
      if @rating < 10
        [
          %q( There might be an opportunity to save costs by reducing your Agreed Supply Capacity (ASC) limit ),
          %q( 
            <p>
              <%= text_explaining_asc_meters_below_limit %>

            </p>
            <p>
              Larger schools often have an Agreed Supply Capacity (ASC) limit, which is an extra charge
              added to your electricity by the Nation Grid, paid through your electricity bill.
              This is an agreed maximum peak power consumption for the school (KVA), and you pay the
              charge to cover the National Grids investment in their distribution network which
              ensures when you need the power they have enough capacity to deliver it.
            </p>
            <p>
              However, often this is set far above the schools needs, so you are paying for the
              additional capacity for no reason. An example might be that your school has an ASC
              of 400 KVA, but your peak demand is only 100 KVA. Which means you are paying for an
              additional 300 KVA on capacity you are unlikely to need, which might cost you
              £3,000 per year. Getting this limit reduced which is simply a matter of asking your
              energy company to reduce the limit (they may ask you to contact their DNO
              (Distributed Network Operator)), might over 10 years save £30,000 for 20 minutes work.
            </p>
            <p>
              To work out your peak used Energy Sparks searches through all yuor schools half hourly meter
              readings and finds the largest reading in kW and compares it with your ASC limit KVA allowing 10%
              margin. Unfortunately Energy Sparks doesnt have access to your peak KVA value but it should be
              within 1% of the kW figure it calculates; you can ask your electricity supplier to provide
              you with your historic monthly peak KVA values just to check Energy Sparks is accurate before
              making a decision. DNO's normally advice setting the ASC limit to 10% above your maximum peak KVA.
            <p>
            <p>
              If you are planning on signifcantly expanding the school in the near future and you expect
              your peak electricity consumption to increase, consider whether a. to reduce the limit
              or b. to reduce it less than the 10% suggestion b. if you get the limit wrong, you will be
              penalised, the charges will be about 3 times your updated ASC charges for every month
              you breach the limit. For all of the above your electricity supplier or DNO should be
              able to provide you with good advice on what to do. You might also expect your peak
              electricity consumption to decline over time as you install more energy efficient equipment
              e.g. computers and LED lighting.
            </p>


            ).gsub(/^  /, '')
          ]
      else
        [
          %q( There are no opportunities for ASC limit saving. ),
          ''
        ]
      end

    description1 = AlertDescriptionDetail.new(:text, ERB.new(text).result(binding))
    @analysis_report.add_detail(description1)
    @analysis_report.rating = 10.0
    @analysis_report.status = :good
  end
end
