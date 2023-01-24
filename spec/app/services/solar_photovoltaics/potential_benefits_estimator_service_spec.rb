# frozen_string_literal: true
require 'pp'

require 'spec_helper'

describe SolarPhotovoltaics::PotentialBenefitsEstimatorService, type: :service do
  let(:service) { SolarPhotovoltaics::PotentialBenefitsEstimatorService.new(meter_collection: @acme_academy, asof_date: Date.parse('2020-12-31')) }

  # using before(:all) here to avoid slow loading of YAML and then
  # running the aggregation code for each test.
  before(:all) do
    @acme_academy = load_unvalidated_meter_collection(school: 'acme-academy')
  end

  context '#create_model' do
    it 'calculates the potential benefits over a geometric sequence of capacity kWp up to 256 for a school with no solar pv' do
      model = service.create_model

      expect(model.optimum_kwp).to round_to_two_digits(52.5) # 52.5
      expect(model.optimum_payback_years).to round_to_two_digits(5.68) # 5.682322708769174
      expect(model.optimum_mains_reduction_percent).to round_to_two_digits(0.1) # 0.10478762755164217
      expect(model.scenarios.size).to round_to_two_digits(9)

      scenarios = model.scenarios

      expect(scenarios[0].kwp).to eq(1)
      expect(scenarios[0].panels).to eq(3)
      expect(scenarios[0].area).to eq(4)
      expect(scenarios[0].solar_consumed_onsite_kwh).to round_to_two_digits(893.95) # 893.9545973935678
      expect(scenarios[0].exported_kwh).to round_to_two_digits(0.0) # 0.0
      expect(scenarios[0].solar_pv_output_kwh).to round_to_two_digits(893.95) # 893.954597393567
      expect(scenarios[0].reduction_in_mains_percent * 100).to round_to_two_digits(0.21) # 0.002068165948887468
      expect(scenarios[0].mains_savings_£).to round_to_two_digits(140.17) # 140.1736542641811
      expect(scenarios[0].solar_pv_output_co2).to round_to_two_digits(169.23) # 169.23840876311736
      expect(scenarios[0].capital_cost_£).to round_to_two_digits(2392.97) # 2392.9653
      expect(scenarios[0].payback_years).to round_to_two_digits(17.07) # 17.07143409053209

      expect(scenarios[1].kwp).to eq(2)
      expect(scenarios[1].panels).to eq(7)
      expect(scenarios[1].area).to eq(10)
      expect(scenarios[1].solar_consumed_onsite_kwh).to round_to_two_digits(1787.91) # 1787.9091947871332
      expect(scenarios[1].exported_kwh).to round_to_two_digits(0.0) # 0.0
      expect(scenarios[1].solar_pv_output_kwh).to round_to_two_digits(1787.91) # 1787.909194787134
      expect(scenarios[1].reduction_in_mains_percent * 100).to round_to_two_digits(0.41) # 0.004136331897774667
      expect(scenarios[1].mains_savings_£).to round_to_two_digits(280.35) # 280.34730852871144
      expect(scenarios[1].solar_pv_output_co2).to round_to_two_digits(338.46) # 338.4568175262347
      expect(scenarios[1].capital_cost_£).to round_to_two_digits(3184.14) # 3184.1412
      expect(scenarios[1].payback_years).to round_to_two_digits(11.36) # 11.357844727351466

      expect(scenarios[2].kwp).to eq(4)
      expect(scenarios[2].panels).to eq(13)
      expect(scenarios[2].area).to eq(19)
      expect(scenarios[2].solar_consumed_onsite_kwh).to round_to_two_digits(3575.82) # 3575.8183895742663
      expect(scenarios[2].exported_kwh).to round_to_two_digits(0.0) # 0.0
      expect(scenarios[2].solar_pv_output_kwh).to round_to_two_digits(3575.82) # 3575.818389574268
      expect(scenarios[2].reduction_in_mains_percent * 100).to round_to_two_digits(0.83) # 0.008272663795547853
      expect(scenarios[2].mains_savings_£).to round_to_two_digits(560.69) # 560.6946170564115
      expect(scenarios[2].solar_pv_output_co2).to round_to_two_digits(676.91) # 676.9136350524694
      expect(scenarios[2].capital_cost_£).to round_to_two_digits(4761.12) # 4761.1248
      expect(scenarios[2].payback_years).to round_to_two_digits(8.49) # 8.491475850072202

      expect(scenarios[3].kwp).to eq(8)
      expect(scenarios[3].panels).to eq(27)
      expect(scenarios[3].area).to eq(39)
      expect(scenarios[3].solar_consumed_onsite_kwh).to round_to_two_digits(7151.64) # 7151.636779148539
      expect(scenarios[3].exported_kwh).to round_to_two_digits(0.0) # 0.0
      expect(scenarios[3].solar_pv_output_kwh).to round_to_two_digits(7151.64) # 7151.636779148536
      expect(scenarios[3].reduction_in_mains_percent * 100).to round_to_two_digits(1.65) # 0.016545327591100552
      expect(scenarios[3].mains_savings_£).to round_to_two_digits(1121.39) # 1121.3892341130122
      expect(scenarios[3].solar_pv_output_co2).to round_to_two_digits(1353.83) # 1353.8272701049389
      expect(scenarios[3].capital_cost_£).to round_to_two_digits(7893.62) # 7893.6192
      expect(scenarios[3].payback_years).to round_to_two_digits(7.04) # 7.0391430199913

      expect(scenarios[4].kwp).to eq(16)
      expect(scenarios[4].panels).to eq(53)
      expect(scenarios[4].area).to eq(76)
      expect(scenarios[4].solar_consumed_onsite_kwh).to round_to_two_digits(14303.27) # 14303.273558297074
      expect(scenarios[4].exported_kwh).to round_to_two_digits(0.0) # 0.0
      expect(scenarios[4].solar_pv_output_kwh).to round_to_two_digits(14303.27) # 14303.273558297073
      expect(scenarios[4].reduction_in_mains_percent * 100).to round_to_two_digits(3.31) # 0.03309065518220407
      expect(scenarios[4].mains_savings_£).to round_to_two_digits(2242.78) # 2242.778468225384
      expect(scenarios[4].solar_pv_output_co2).to round_to_two_digits(2707.65) # 2707.6545402098777
      expect(scenarios[4].capital_cost_£).to round_to_two_digits(14072.72) # 14072.7168
      expect(scenarios[4].payback_years).to round_to_two_digits(6.27) # 6.274679822093685

      expect(scenarios[5].kwp).to round_to_two_digits(32)
      expect(scenarios[5].panels).to round_to_two_digits(107)
      expect(scenarios[5].area).to round_to_two_digits(154)
      expect(scenarios[5].solar_consumed_onsite_kwh).to round_to_two_digits(28554.86) # 28554.856062377454
      expect(scenarios[5].exported_kwh).to round_to_two_digits(51.69) # 51.691054216699065
      expect(scenarios[5].solar_pv_output_kwh).to round_to_two_digits(28606.55) # 28606.547116594145
      expect(scenarios[5].reduction_in_mains_percent).to round_to_two_digits(0.07) # 0.06606172299553545
      expect(scenarios[5].mains_savings_£).to round_to_two_digits(4477.39) # 4477.390491042279
      expect(scenarios[5].solar_pv_output_co2).to round_to_two_digits(5415.31) # 5415.309080419755
      expect(scenarios[5].capital_cost_£).to round_to_two_digits(26087.35) # 26087.3472
      expect(scenarios[5].payback_years).to round_to_two_digits(5.82) # 5.823101009541616
            
      expect(scenarios[6].kwp).to eq(52.5)
      expect(scenarios[6].panels).to eq(175)
      expect(scenarios[6].area).to eq(252)
      expect(scenarios[6].solar_consumed_onsite_kwh).to round_to_two_digits(45293.94) # 45293.93854982251
      expect(scenarios[6].exported_kwh).to round_to_two_digits(1638.68) # 1638.67781333994
      expect(scenarios[6].solar_pv_output_kwh).to round_to_two_digits(46932.62) # 46932.61636316246
      expect(scenarios[6].reduction_in_mains_percent * 100).to round_to_two_digits(10.48) # 0.10478762755164217
      expect(scenarios[6].mains_savings_£).to round_to_two_digits(7100.28) # 7100.275782503792
      expect(scenarios[6].solar_pv_output_co2).to round_to_two_digits(8884.49) # 8884.491460063697
      expect(scenarios[6].capital_cost_£).to round_to_two_digits(40811.63) # 40811.633125
      expect(scenarios[6].payback_years).to round_to_two_digits(5.68) # 5.682322708769174
          
      expect(scenarios[7].kwp).to eq(64)
      expect(scenarios[7].panels).to eq(213)
      expect(scenarios[7].area).to eq(307)
      expect(scenarios[7].solar_consumed_onsite_kwh).to round_to_two_digits(53186.56) # 53186.555323147804
      expect(scenarios[7].exported_kwh).to round_to_two_digits(4026.54) # 4026.538910040475
      expect(scenarios[7].solar_pv_output_kwh).to round_to_two_digits(57213.09) # 57213.09423318829
      expect(scenarios[7].reduction_in_mains_percent * 100).to round_to_two_digits(12.3) # 0.12304721400692871
      expect(scenarios[7].mains_savings_£).to round_to_two_digits(8334.56) # 8334.556977244858
      expect(scenarios[7].solar_pv_output_co2).to round_to_two_digits(10830.62) # 10830.61816083951
      expect(scenarios[7].capital_cost_£).to round_to_two_digits(48742.35) # 48742.3488
      expect(scenarios[7].payback_years).to round_to_two_digits(5.71) # 5.710287211159089
          
      expect(scenarios[8].kwp).to eq(128)
      expect(scenarios[8].panels).to eq(427)
      expect(scenarios[8].area).to eq(615)
      expect(scenarios[8].solar_consumed_onsite_kwh).to round_to_two_digits(85201.53) # 85201.53193961504
      expect(scenarios[8].exported_kwh).to round_to_two_digits(29224.66) # 29224.65652676189
      expect(scenarios[8].solar_pv_output_kwh).to round_to_two_digits(114426.19) # 114426.18846637658
      expect(scenarios[8].reduction_in_mains_percent * 100).to round_to_two_digits(19.71) # 0.1971139335983544
      expect(scenarios[8].mains_savings_£).to round_to_two_digits(13326.38) # 13326.379573018603
      expect(scenarios[8].solar_pv_output_co2).to round_to_two_digits(21661.24) # 21661.23632167902
      expect(scenarios[8].capital_cost_£).to round_to_two_digits(88555.32) # 88555.3152
      expect(scenarios[8].payback_years).to round_to_two_digits(5.99) # 5.9884796009295185
    end
  end
end
