require 'spec_helper'

describe ChartManager do

  context '#build_chart_config' do
    let(:chart_name)   { :benchmark }
    let(:chart_config) { ChartManager::STANDARD_CHART_CONFIGURATION[chart_name] }

    it 'returns original if no inheritance' do
      expect( ChartManager.build_chart_config(chart_config) ).to eql chart_config
    end

    context 'when chart inherits from another' do
      let(:chart_name)    { :benchmark_kwh }
      let(:new_config)    { ChartManager.build_chart_config(chart_config) }

      it 'resolves inherited properties' do
        expect(new_config[:chart1_type]).to eql(:bar)
      end

      it 'preserves child properties' do
        expect(new_config[:yaxis_units]).to eql(:kwh) #not :£
      end

      it 'removes inherit_from' do
        expect(new_config[:inherits_from]).to be_nil
      end
    end
  end

  context '#resolve_chart_inheritance' do
    let(:chart_name)    { :benchmark }
    let(:chart_config)  { ChartManager::STANDARD_CHART_CONFIGURATION[chart_name] }
    let(:school)        { nil }
    let(:chart_manager) { ChartManager.new(school) }

    it 'resolves config' do
      expect( chart_manager.resolve_chart_inheritance(chart_config) ).to eql chart_config
    end
  end

  context '#get_chart_config' do
    let(:chart_name)    { :benchmark }
    let(:school)        { nil }
    let(:chart_manager) { ChartManager.new(school) }

    let(:overrides)     { {this: :that} }

    it 'retrieves config' do
      expect( chart_manager.get_chart_config(chart_name) ).to eql ChartManager::STANDARD_CHART_CONFIGURATION[chart_name]
    end

    it 'applies overrides' do
      config = chart_manager.get_chart_config(chart_name, overrides)
      expect(config[:this]).to eql :that
    end

  end
end
