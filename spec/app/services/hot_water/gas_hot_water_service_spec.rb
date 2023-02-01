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
      expect(model.investment_choices.existing_gas.annual_co2).to round_to_two_digits(14_677.57) # 14677.565516249997
      expect(model.investment_choices.existing_gas.annual_kwh).to round_to_two_digits(69_893.17) # 69893.16912499999
      expect(model.investment_choices.existing_gas.annual_£).to round_to_two_digits(2096.8) # 2096.795073749998
      expect(model.investment_choices.existing_gas.capex).to round_to_two_digits(0) # 0.0
      expect(model.investment_choices.existing_gas.efficiency).to round_to_two_digits(0.39) # 0.3910029812945617
      expect(model.investment_choices.gas_better_control.saving_kwh).to round_to_two_digits(19_798.90) # 19_798.904124999986
      expect(model.investment_choices.gas_better_control.saving_kwh_percent).to round_to_two_digits(0.28) # 0.2832738073386079
      expect(model.investment_choices.gas_better_control.saving_£).to round_to_two_digits(593.97) # 593.9671237499992
      expect(model.investment_choices.gas_better_control.saving_£_percent).to round_to_two_digits(0.28) # 0.28327380733860796
      expect(model.investment_choices.gas_better_control.saving_co2).to round_to_two_digits(4157.77) # 4157.769866249997
      expect(model.investment_choices.gas_better_control.saving_co2_percent).to round_to_two_digits(0.28) # 0.2832738073386079
      expect(model.investment_choices.gas_better_control.payback_years).to round_to_two_digits(0.0) # 0.0
      expect(model.investment_choices.gas_better_control.annual_kwh).to round_to_two_digits(50_094.27) # 50_094.265
      expect(model.investment_choices.gas_better_control.annual_£).to round_to_two_digits(1502.83) # 1502.827949999999
      expect(model.investment_choices.gas_better_control.annual_co2).to round_to_two_digits(10_519.8) # 10_519.79565
      expect(model.investment_choices.gas_better_control.capex).to round_to_two_digits(0.0) # 0.0
      expect(model.investment_choices.gas_better_control.efficiency).to round_to_two_digits(0.55) # 0.5455402429799101

      expect(model.investment_choices.point_of_use_electric.saving_kwh).to round_to_two_digits(36_304.98) # 36_304.981624999986
      expect(model.investment_choices.point_of_use_electric.saving_kwh_percent).to round_to_two_digits(0.52) # 0.5194353336600116
      expect(model.investment_choices.point_of_use_electric.saving_£).to round_to_two_digits(-3009.95) # -3009.9529537500025
      expect(model.investment_choices.point_of_use_electric.saving_£_percent).to round_to_two_digits(-1.44) # -1.4355017290110634
      expect(model.investment_choices.point_of_use_electric.saving_co2).to round_to_two_digits(9639.34) # 9639.337391249997
      expect(model.investment_choices.point_of_use_electric.saving_co2_percent).to round_to_two_digits(0.66) # 0.6567395240428654
      expect(model.investment_choices.point_of_use_electric.payback_years).to round_to_two_digits(-6.51) # -6.511729685203551
      expect(model.investment_choices.point_of_use_electric.annual_kwh).to round_to_two_digits(33_588.19) # 33_588.1875
      expect(model.investment_choices.point_of_use_electric.annual_£).to round_to_two_digits(5106.75) # 5106.748027500001
      expect(model.investment_choices.point_of_use_electric.annual_co2).to round_to_two_digits(5038.23) # 5038.228125
      expect(model.investment_choices.point_of_use_electric.capex).to round_to_two_digits(19_600.0) # 19_600.0
      expect(model.investment_choices.point_of_use_electric.efficiency).to round_to_two_digits(0.81) # 0.813632396806169

      expect(model.efficiency_breakdowns.daily.kwh.school_day_open).to round_to_two_digits(256.89) # 256.89366666666666
      expect(model.efficiency_breakdowns.daily.kwh.school_day_closed).to round_to_two_digits(32.39) # 32.387866666666575
      expect(model.efficiency_breakdowns.daily.kwh.holiday).to round_to_two_digits(144.5) # 144.49537500000002
      expect(model.efficiency_breakdowns.daily.kwh.weekend).to round_to_two_digits(4.28) # 4.2845
      expect(model.efficiency_breakdowns.daily.£.school_day_open).to round_to_two_digits(7.71) # 7.706809999999995
      expect(model.efficiency_breakdowns.daily.£.school_day_closed).to round_to_two_digits(0.97) # 0.9716359999999965
      expect(model.efficiency_breakdowns.daily.£.holiday).to round_to_two_digits(4.33) # 4.334861249999998
      expect(model.efficiency_breakdowns.daily.£.weekend).to round_to_two_digits(0.13) # 0.12853499999999993

      expect(model.efficiency_breakdowns.annual.kwh.school_day_open).to round_to_two_digits(50_094.27) # 50_094.265
      expect(model.efficiency_breakdowns.annual.kwh.school_day_closed).to round_to_two_digits(6315.63) # 6315.633999999982
      expect(model.efficiency_breakdowns.annual.kwh.holiday).to round_to_two_digits(13_149.08) # 13_149.079125000002
      expect(model.efficiency_breakdowns.annual.kwh.weekend).to round_to_two_digits(334.19) # 334.19100000000003
      expect(model.efficiency_breakdowns.annual.£.school_day_open).to round_to_two_digits(1502.83) # 1502.827949999999
      expect(model.efficiency_breakdowns.annual.£.school_day_closed).to round_to_two_digits(189.47) # 189.46901999999932
      expect(model.efficiency_breakdowns.annual.£.holiday).to round_to_two_digits(394.47) # 394.47237374999975
      expect(model.efficiency_breakdowns.annual.£.weekend).to round_to_two_digits(10.03) # 10.025729999999994
    end
  end
end
