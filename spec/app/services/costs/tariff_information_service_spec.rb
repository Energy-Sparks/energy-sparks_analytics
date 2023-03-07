require 'spec_helper'

describe Costs::TariffInformationService, type: :service do

  # using before(:all) here to avoid slow loading of YAML and then
  # running the aggregation code for each test.
  before(:all) do
    @acme_academy = load_unvalidated_meter_collection(school: 'acme-academy')
  end

  let(:service)           { Costs::TariffInformationService.new(aggregate_meter, analysis_start_date, analysis_end_date)}
  let(:aggregate_meter)   { @acme_academy.aggregated_electricity_meters }
  let(:analysis_end_date) { aggregate_meter.amr_data.end_date }
  let(:analysis_start_date) { [analysis_end_date - 365 - 364, aggregate_meter.amr_data.start_date].max}

  it 'should do something' do
    expect(service.incomplete_coverage?).to be false
    expect(service.percentage_with_real_tariffs).to eq 0.0
    expect(service.periods_with_missing_tariffs).to eq [ [Date.new(2020,7,14), Date.new(2022,7,13)] ]
    expect(service.periods_with_tariffs).to eq []
  end
end
