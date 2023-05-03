require 'spec_helper'

describe Costs::TariffInformationService, type: :service do

  # using before(:all) here to avoid slow loading of YAML and then
  # running the aggregation code for each test.
  before(:all) do
    @acme_academy = load_unvalidated_meter_collection(school: 'acme-academy')
  end

  let(:meter)             { @acme_academy.aggregated_electricity_meters }
  let(:analysis_end_date) { meter.amr_data.end_date }
  let(:analysis_start_date) { [analysis_end_date - 365 - 364, meter.amr_data.start_date].max}
  let(:service)           { Costs::TariffInformationService.new(meter, analysis_start_date, analysis_end_date)}

  context 'checking tariff coverage' do
    it 'should have expected coverage' do
      expect(service.incomplete_coverage?).to be false
      expect(service.percentage_with_real_tariffs).to eq 0.0
      expect(service.periods_with_missing_tariffs).to eq [ [Date.new(2020,7,14), Date.new(2022,7,13)] ]
      expect(service.periods_with_tariffs).to eq []
    end
  end

  context '#tariffs' do
    let(:meter) { @acme_academy.electricity_meters.last }

    let(:first_range)  { Date.new(2022,4,1)..Date.new(2022,7,13)}
    let(:second_range) { Date.new(2020,7,14)..Date.new(2022,3,31)}

    it 'should return list of tariffs' do
      tariffs = service.tariffs

      first_tariff = tariffs[first_range]
      expect(first_tariff).to_not be_nil
      expect(first_tariff.name).to eq 'System Wide Electricity Accounting Tariff'
      expect(first_tariff.fuel_type).to eq :electricity
      expect(first_tariff.type).to be_nil
      expect(first_tariff.source).to be_nil
      expect(first_tariff.real).to eq false

      second_tariff = tariffs[second_range]
      expect(second_tariff).to_not be_nil
      expect(second_tariff.name).to eq 'Philips test'
      expect(second_tariff.fuel_type).to eq :electricity
      expect(second_tariff.type).to eq :differential
      expect(second_tariff.source).to eq :manually_entered
      expect(second_tariff.start_date).to eq Date.new(2020,4,1)
      expect(second_tariff.end_date).to eq Date.new(2022,3,31)
      expect(second_tariff.real).to eq true
    end
  end
end
