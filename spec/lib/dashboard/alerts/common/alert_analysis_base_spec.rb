require 'spec_helper'
require 'dashboard'

#Custom subclass for testing assigning of variables in base class methods.
#For most complex tests use a proper double
class CustomAnalysisAlert < AlertAnalysisBase
  def initialize(meter_collection, report_type)
    super(meter_collection, report_type)
  end
  def aggregate_meter
    nil
  end
end

describe AlertAnalysisBase do

  context '#set_savings_capital_costs_payback' do
    let(:meter_collection)  { double('meter-collection') }
    let(:alert)             { CustomAnalysisAlert.new(meter_collection, 'analysis-test')}

    before(:each) do
      allow(meter_collection).to receive(:aggregated_heat_meters).and_return(nil)
    end

    it 'assigns one_year_saving_co2' do
      alert.send(:set_savings_capital_costs_payback, 0.0, 0.0, 100.0)
      expect(alert.one_year_saving_co2).to eq(100.0)
      expect(alert.ten_year_saving_co2).to eq(1000.0)
    end

    it 'assigns average_one_year_saving_£' do
      alert.send(:set_savings_capital_costs_payback, 100.0, 0.0, 0.0)
      expect(alert.one_year_saving_£).to eq(Range.new(100.0, 100.0))
      expect(alert.ten_year_saving_£).to eq(Range.new(1000.0, 1000.0))
      expect(alert.average_one_year_saving_£).to eq 100.0
      expect(alert.average_ten_year_saving_£).to eq 1000.0
    end

    it 'assigns average_one_year_saving_£ using ranges' do
      alert.send(:set_savings_capital_costs_payback, Range.new(100.0,200.0), 0.0, 0.0)
      expect(alert.one_year_saving_£).to eq(Range.new(100.0, 200.0))
      expect(alert.ten_year_saving_£).to eq(Range.new(1000.0, 2000.0))
      expect(alert.average_one_year_saving_£).to eq 150.0
      expect(alert.average_ten_year_saving_£).to eq 1500.0
    end

    it 'assigns average_capital_cost' do
      alert.send(:set_savings_capital_costs_payback, 0.0, 100.0, 0.0)
      expect(alert.capital_cost).to eq(Range.new(100.0, 100.0))
      expect(alert.average_capital_cost).to eq 100.0
    end

    it 'assigns average_capital_cost with ranges' do
      alert.send(:set_savings_capital_costs_payback, 0.0, Range.new(100.0,200.0), 0.0)
      expect(alert.capital_cost).to eq(Range.new(100.0, 200.0))
      expect(alert.average_capital_cost).to eq 150.0
    end

    it 'assigns average_payback_years' do
      alert.send(:set_savings_capital_costs_payback, 0.0, 0.0, 0.0)
      expect(alert.average_payback_years).to eq 0.0

      alert.send(:set_savings_capital_costs_payback, 100.0, 200.0, 0.0)
      expect(alert.average_payback_years).to eq 2.0
    end

    it 'assigns one_year_saving_kwh'
  end

end
