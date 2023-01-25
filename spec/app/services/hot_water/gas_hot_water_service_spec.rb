# frozen_string_literal: true

require 'spec_helper'

describe HotWater::GasHotWaterService do
  let(:service) { HotWater::GasHotWaterService.new(meter_collection: @acme_academy) }

  # using before(:all) here to avoid slow loading of YAML and then
  # running the aggregation code for each test.
  before(:all) do
    @acme_academy = load_unvalidated_meter_collection(school: 'acme-academy')
  end

  context '#create_model' do
    it 'creates a model for results of a heating thermostatic analysis' do
      model = service.create_model
      expect(model.investment_choices.existing_gas.annual_co2).to eq(14_677.565516249997) # 14677.565516249997
      expect(model.investment_choices.existing_gas.annual_kwh).to eq(69_893.16912499999) # 69893.16912499999
      expect(model.investment_choices.existing_gas.annual_£).to eq(2096.795073749998) # 2096.795073749998
      expect(model.investment_choices.existing_gas.capex).to eq(0) # 0.0
      expect(model.investment_choices.existing_gas.efficiency).to eq(0.3910029812945617) # 0.3910029812945617

      expect(model.investment_choices.gas_better_control.saving_kwh).to eq(19_798.904124999986)
      expect(model.investment_choices.gas_better_control.saving_kwh_percent).to eq(0.2832738073386079)
      expect(model.investment_choices.gas_better_control.saving_£).to eq(593.9671237499992)
      expect(model.investment_choices.gas_better_control.saving_£_percent).to eq(0.28327380733860796)
      expect(model.investment_choices.gas_better_control.saving_co2).to eq(4157.769866249997)
      expect(model.investment_choices.gas_better_control.saving_co2_percent).to eq(0.2832738073386079)
      expect(model.investment_choices.gas_better_control.payback_years).to eq(0.0)
      expect(model.investment_choices.gas_better_control.annual_kwh).to eq(50_094.265)
      expect(model.investment_choices.gas_better_control.annual_£).to eq(1502.827949999999)
      expect(model.investment_choices.gas_better_control.annual_co2).to eq(10_519.79565)
      expect(model.investment_choices.gas_better_control.capex).to eq(0.0)
      expect(model.investment_choices.gas_better_control.efficiency).to eq(0.5455402429799101)

      expect(model.investment_choices.point_of_use_electric.saving_kwh).to eq(36_304.981624999986)
      expect(model.investment_choices.point_of_use_electric.saving_kwh_percent).to eq(0.5194353336600116)
      expect(model.investment_choices.point_of_use_electric.saving_£).to eq(-3009.9529537500025)
      expect(model.investment_choices.point_of_use_electric.saving_£_percent).to eq(-1.4355017290110634)
      expect(model.investment_choices.point_of_use_electric.saving_co2).to eq(9639.337391249997)
      expect(model.investment_choices.point_of_use_electric.saving_co2_percent).to eq(0.6567395240428654)
      expect(model.investment_choices.point_of_use_electric.payback_years).to eq(-6.511729685203551)
      expect(model.investment_choices.point_of_use_electric.annual_kwh).to eq(33_588.1875)
      expect(model.investment_choices.point_of_use_electric.annual_£).to eq(5106.748027500001)
      expect(model.investment_choices.point_of_use_electric.annual_co2).to eq(5038.228125)
      expect(model.investment_choices.point_of_use_electric.capex).to eq(19_600.0)
      expect(model.investment_choices.point_of_use_electric.efficiency).to eq(0.813632396806169)
    end
  end
end
