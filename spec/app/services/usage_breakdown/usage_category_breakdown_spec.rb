require 'spec_helper'

describe UsageBreakdown::UsageCategoryBreakdown, type: :service do
  Object.const_set('Rails', true) # Otherwise the test fails at line 118 (RecordTestTimes) in ChartManager
  let(:meter_collection) { load_unvalidated_meter_collection(school: 'acme-academy') }
  let(:service) { UsageBreakdown::UsageBreakdownService.new(meter_collection: meter_collection, fuel_type: :electricity).usage_breakdown }

  context '#potential_saving_kwh' do
    it 'calculates the potential savings in kwh' do
      expect(service.potential_saving_kwh).to round_to_two_digits(131741.33) # 131741.32666666666
    end
  end

  context '#total_annual_kwh' do
    it 'calculates the total annual kwh' do 
      expect(service.total_annual_kwh).to round_to_two_digits(467398.40) # 467398.3999999999
    end
  end

  context '#potential_saving_£' do
    it 'calculates the potential savings pounds sterling' do
      expect(service.potential_saving_£).to round_to_two_digits(20029.15) # 20029.152587063218
    end
  end

  context '#total_annual_£' do
    it 'total annual cost in pounds sterling' do
      expect(service.total_annual_£).to round_to_two_digits(71060.42) # 71060.41900000001      
    end
  end

  context '#total_annual_kwh' do
    it 'calculates the total annual kwh' do
      expect(service.total_annual_kwh).to round_to_two_digits(467398.40) # 467398.3999999999
    end
  end

  context '#total_annual_co2' do
    it 'calculates the total annual co2' do
      expect(service.total_annual_co2).to round_to_two_digits(88492.64) # 88492.6392
    end
  end

  context '#percent_improvement_to_exemplar' do
    it 'calculates the percentage improvement in relation to an examplar school' do
      expect(service.percent_improvement_to_exemplar).to round_to_two_digits(0.28) # 0.28186088498947937
    end
  end

  context '#exemplar_out_of_hours_use_percent' do
    it 'returns the percent value of an examplar schools out of hours use' do
      service.instance_variable_set(:@fuel_type, :electricity)
      expect(service.exemplar_out_of_hours_use_percent).to eq(BenchmarkMetrics::EXEMPLAR_OUT_OF_HOURS_USE_PERCENT_ELECTRICITY)
      service.instance_variable_set(:@fuel_type, :gas)
      expect(service.exemplar_out_of_hours_use_percent).to eq(BenchmarkMetrics::EXEMPLAR_OUT_OF_HOURS_USE_PERCENT_GAS)
    end
  end
end
