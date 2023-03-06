require 'spec_helper'

describe Costs::TariffInformationService do

  # using before(:all) here to avoid slow loading of YAML and then
  # running the aggregation code for each test.
  before(:all) do
    @acme_academy = load_unvalidated_meter_collection(school: 'acme-academy')
  end

  let(:service)           { Costs::TariffInformationService.new(aggregate_meter, analysis_start_date, analysis_end_date)}
  let(:aggregate_meter)   { @acme_academy.aggregated_electricity_meters }
  #FIXME?
  let(:analysis_end_date) { aggregate_meter.amr_data.end_date }
  let(:analysis_start_date) { [analysis_end_date - 365 - 364, aggregate_meter.amr_data.start_date].max}

  it 'should do something' do
    meter_cost = MeterCost.new(@acme_academy, aggregate_meter, false, true, analysis_start_date, analysis_end_date)
    puts meter_cost.percent_real
    puts meter_cost.incomplete_coverage?
    #    puts meter_cost.intro_to_meter

    puts service.incomplete_coverage?
    puts service.percentage_with_real_tariffs
    puts service.periods_with_missing_tariffs.inspect
    puts service.periods_with_tariffs.inspect
  end
end
