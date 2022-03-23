require 'spec_helper'

describe TargetsProgress do

  let(:months)                    { ['jan', 'feb'] }
  let(:fuel_type)                 { :electricity }

  let(:monthly_usage_kwh)         { [10,20] }
  let(:monthly_targets_kwh)       { [8,15] }
  let(:monthly_performance)       { [-0.25,0.35] }

  let(:cumulative_usage_kwh)      { [10,30] }
  let(:cumulative_targets_kwh)    { [8,25] }
  let(:cumulative_performance)    { [-0.99,0.99] }

  let(:partial_months)            { [false, true] }
  let(:percentage_synthetic)      { [0.0, 0.5]}

  let(:progress) do
    TargetsProgress.new(
        fuel_type: fuel_type,
        months: months,
        monthly_targets_kwh: monthly_targets_kwh,
        monthly_usage_kwh: monthly_usage_kwh,
        monthly_performance: monthly_performance,
        cumulative_targets_kwh: cumulative_targets_kwh,
        cumulative_usage_kwh: cumulative_usage_kwh,
        cumulative_performance: cumulative_performance,
        cumulative_performance_versus_synthetic_last_year: cumulative_performance,
        monthly_performance_versus_synthetic_last_year: monthly_performance,
        partial_months: partial_months,
        percentage_synthetic: percentage_synthetic
    )
  end

  context '#monthly_targets_kwh' do
    it 'returns expected data' do
      expect(progress.monthly_targets_kwh["jan"]).to eq 8
      expect(progress.monthly_targets_kwh["feb"]).to eq 15
    end
  end

  context '#monthly_usage_kwh' do
    it 'returns expected data' do
      expect(progress.monthly_usage_kwh["jan"]).to eq 10
      expect(progress.monthly_usage_kwh["feb"]).to eq 20
    end
  end

  context '#monthly_performance' do
    it 'returns expected data' do
      expect(progress.monthly_performance['jan']).to eq -0.25
      expect(progress.monthly_performance['feb']).to eq 0.35
    end
  end

  context '#cumulative_usage_kwh' do
    it 'returns expected data' do
      expect(progress.cumulative_usage_kwh["jan"]).to eq 10
      expect(progress.cumulative_usage_kwh["feb"]).to eq 30
    end
  end

  context '#cumulative_targets_kwh' do
    it 'returns expected data' do
      expect(progress.cumulative_targets_kwh["jan"]).to eq 8
      expect(progress.cumulative_targets_kwh["feb"]).to eq 25
    end
  end

  context '#cumulative_performance' do
    it 'returns expected data' do
      expect(progress.cumulative_performance['jan']).to eql -0.99
      expect(progress.cumulative_performance['feb']).to eql 0.99
    end
  end

  context '#percentage_synthetic' do
    it 'returns expected data' do
      expect(progress.percentage_synthetic['jan']).to eql 0.0
      expect(progress.percentage_synthetic['feb']).to eql 0.5
    end
  end

  context '#partial_months' do
    it 'returns expected data' do
      expect(progress.partial_months['jan']).to eq false
      expect(progress.partial_months['feb']).to eq true
    end
  end

  context '#current_cumulative_usage_kwh' do
    it 'returns expected data' do
      expect(progress.current_cumulative_usage_kwh).to eq 30
    end
  end

  context '#current_cumulative_performance' do
    it 'returns expected data' do
      expect(progress.current_cumulative_performance).to eq 0.99
    end
  end

  context '#months' do
    it 'returns expected data' do
      expect(progress.months).to eq ['jan', 'feb']
    end
  end

  context '#partial_consumption_data?' do
    it 'returns expected data' do
      expect(progress.partial_consumption_data?).to be true
    end
  end

  context '#partial_target_data?' do
    it 'returns expected data' do
      expect(progress.partial_target_data?).to be false
    end
  end

  context '#reporting_period_before_consumption_data?' do
    it 'returns expected data' do
      expect(progress.reporting_period_before_consumption_data?).to be false
    end
  end

  context '#targets_derived_from_synthetic_data?' do
    it 'returns expected data' do
      expect(progress.targets_derived_from_synthetic_data?).to eql true
    end
  end
end
