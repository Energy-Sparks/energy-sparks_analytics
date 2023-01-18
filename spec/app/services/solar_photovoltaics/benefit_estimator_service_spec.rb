# frozen_string_literal: true
require 'pp'

require 'spec_helper'

describe SolarPhotovoltaics::BenefitEstimatorService, type: :service do
  let(:service) { SolarPhotovoltaics::BenefitEstimatorService.new(school: @acme_academy, asof_date: Date.parse('2020-12-31')) }

  # using before(:all) here to avoid slow loading of YAML and then
  # running the aggregation code for each test.
  before(:all) do
    @acme_academy = load_unvalidated_meter_collection(school: 'acme-academy')
  end

  context '' do
    it '' do
      service.calculate_benefits!
      # puts service.solar_pv_scenario_table.inspect
      expect(service.solar_pv_scenario_table).to eq(
        [
          [1, 3, 4, 893.9545973935678, 0.0, 893.954597393567, 0.002068165948887468, 140.1736542641811, 169.22840876311736, 2392.9653, 17.07143409053209],
          [2, 7, 10, 1787.9091947871332, 0.0, 1787.909194787134, 0.004136331897774667, 280.34730852871144, 338.4568175262347, 3184.1412, 11.357844727351466],
          [4, 13, 19, 3575.8183895742663, 0.0, 3575.818389574268, 0.008272663795547853, 560.6946170564115, 676.9136350524694, 4761.1248, 8.491475850072202],
          [8, 27, 39, 7151.636779148539, 0.0, 7151.636779148536, 0.016545327591100552, 1121.3892341130122, 1353.8272701049389, 7893.6192, 7.0391430199913],
          [16, 53, 76, 14_303.273558297074, 0.0, 14_303.273558297073, 0.03309065518220407, 2242.778468225384, 2707.6545402098777, 14_072.7168, 6.274679822093685],
          [32, 107, 154, 28_554.856062377454, 51.691054216699065, 28_606.547116594145, 0.06606172299553545, 4479.975043753114, 5415.309080419755, 26_087.3472, 5.823101009541616],
          [52.5, 175, 252, 45_293.93854982251, 1638.67781333994, 46_932.61636316246, 0.10478762755164217, 7182.209673170789, 8884.491460063697, 40_811.633125, 5.682322708769174],
          [64, 213, 307, 53_186.555323147804, 4026.538910040475, 57_213.09423318829, 0.12304721400692871, 8535.883922746882, 10_830.61816083951, 48_742.3488, 5.710287211159089],
          [128, 427, 615, 85_201.53193961504, 29_224.65652676189, 114_426.18846637658, 0.1971139335983544, 14_787.612399356698, 21_661.23632167902, 88_555.3152, 5.9884796009295185]
        ]
      )

      expect(service.one_year_saving_£current).to eq(7182.209673170789)

      expect(service.scenarios).to eq(
        [
          {
            :kwp=>1,
            :panels=>3,
            :area=>4,
            :existing_annual_kwh=>432245.09999999986,
            :existing_annual_£=>65366.193000000036,
            :new_mains_consumption_kwh=>431351.1454026064,
            :new_mains_consumption_£=>65226.019345735855,
            :reduction_in_mains_percent=>0.002068165948887468,
            :solar_consumed_onsite_kwh=>893.9545973935678,
            :exported_kwh=>0.0,
            :solar_pv_output_kwh=>893.954597393567,
            :solar_pv_output_co2=>169.22840876311736,
            :old_mains_cost_£=>65366.193000000036,
            :new_mains_cost_£=>65226.019345735855,
            :export_income_£=>0.0,
            :mains_savings_£=>140.1736542641811,
            :total_annual_saving_£=>140.1736542641811,
            :total_annual_saving_co2=>169.22840876311736,
            :capital_cost_£=>2392.9653,
            :payback_years=>17.07143409053209
          },
          {
            :kwp=>2,
            :panels=>7,
            :area=>10,
            :existing_annual_kwh=>432245.09999999986,
            :existing_annual_£=>65366.193000000036,
            :new_mains_consumption_kwh=>430457.19080521306,
            :new_mains_consumption_£=>65085.845691471324,
            :reduction_in_mains_percent=>0.004136331897774667,
            :solar_consumed_onsite_kwh=>1787.9091947871332,
            :exported_kwh=>0.0,
            :solar_pv_output_kwh=>1787.909194787134,
            :solar_pv_output_co2=>338.4568175262347,
            :old_mains_cost_£=>65366.193000000036,
            :new_mains_cost_£=>65085.845691471324,
            :export_income_£=>0.0,
            :mains_savings_£=>280.34730852871144,
            :total_annual_saving_£=>280.34730852871144,
            :total_annual_saving_co2=>338.4568175262347,
            :capital_cost_£=>3184.1412,
            :payback_years=>11.357844727351466
          },
          {
            :kwp=>4,
            :panels=>13,
            :area=>19,
            :existing_annual_kwh=>432245.09999999986,
            :existing_annual_£=>65366.193000000036,
            :new_mains_consumption_kwh=>428669.2816104269,
            :new_mains_consumption_£=>64805.498382943624,
            :reduction_in_mains_percent=>0.008272663795547853,
            :solar_consumed_onsite_kwh=>3575.8183895742663,
            :exported_kwh=>0.0,
            :solar_pv_output_kwh=>3575.818389574268,
            :solar_pv_output_co2=>676.9136350524694,
            :old_mains_cost_£=>65366.193000000036,
            :new_mains_cost_£=>64805.498382943624,
            :export_income_£=>0.0,
            :mains_savings_£=>560.6946170564115,
            :total_annual_saving_£=>560.6946170564115,
            :total_annual_saving_co2=>676.9136350524694,
            :capital_cost_£=>4761.1248,
            :payback_years=>8.491475850072202
          },
          {
            :kwp=>8,
            :panels=>27,
            :area=>39,
            :existing_annual_kwh=>432245.09999999986,
            :existing_annual_£=>65366.193000000036,
            :new_mains_consumption_kwh=>425093.46322085185,
            :new_mains_consumption_£=>64244.80376588702,
            :reduction_in_mains_percent=>0.016545327591100552,
            :solar_consumed_onsite_kwh=>7151.636779148539,
            :exported_kwh=>0.0,
            :solar_pv_output_kwh=>7151.636779148536,
            :solar_pv_output_co2=>1353.8272701049389,
            :old_mains_cost_£=>65366.193000000036,
            :new_mains_cost_£=>64244.80376588702,
            :export_income_£=>0.0,
            :mains_savings_£=>1121.3892341130122,
            :total_annual_saving_£=>1121.3892341130122,
            :total_annual_saving_co2=>1353.8272701049389,
            :capital_cost_£=>7893.6192,
            :payback_years=>7.0391430199913
          },
          {
            :kwp=>16,
            :panels=>53,
            :area=>76,
            :existing_annual_kwh=>432245.09999999986,
            :existing_annual_£=>65366.193000000036,
            :new_mains_consumption_kwh=>417941.82644170255,
            :new_mains_consumption_£=>63123.41453177465,
            :reduction_in_mains_percent=>0.03309065518220407,
            :solar_consumed_onsite_kwh=>14303.273558297074,
            :exported_kwh=>0.0,
            :solar_pv_output_kwh=>14303.273558297073,
            :solar_pv_output_co2=>2707.6545402098777,
            :old_mains_cost_£=>65366.193000000036,
            :new_mains_cost_£=>63123.41453177465,
            :export_income_£=>0.0,
            :mains_savings_£=>2242.778468225384,
            :total_annual_saving_£=>2242.778468225384,
            :total_annual_saving_co2=>2707.6545402098777,
            :capital_cost_£=>14072.7168,
            :payback_years=>6.274679822093685
          },
          {
            :kwp=>32,
            :panels=>107,
            :area=>154,
            :existing_annual_kwh=>432245.09999999986,
            :existing_annual_£=>65366.193000000036,
            :new_mains_consumption_kwh=>403690.24393762235,
            :new_mains_consumption_£=>60888.80250895776,
            :reduction_in_mains_percent=>0.06606172299553545,
            :solar_consumed_onsite_kwh=>28554.856062377454,
            :exported_kwh=>51.691054216699065,
            :solar_pv_output_kwh=>28606.547116594145,
            :solar_pv_output_co2=>5415.309080419755,
            :old_mains_cost_£=>65366.193000000036,
            :new_mains_cost_£=>60888.80250895776,
            :export_income_£=>2.5845527108349535,
            :mains_savings_£=>4477.390491042279,
            :total_annual_saving_£=>4479.975043753114,
            :total_annual_saving_co2=>5415.309080419755,
            :capital_cost_£=>26087.3472,
            :payback_years=>5.823101009541616
          },
          {
            :kwp=>52.5,
            :panels=>175,
            :area=>252,
            :existing_annual_kwh=>432245.09999999986,
            :existing_annual_£=>65366.193000000036,
            :new_mains_consumption_kwh=>386951.16145017755,
            :new_mains_consumption_£=>58265.917217496244,
            :reduction_in_mains_percent=>0.10478762755164217,
            :solar_consumed_onsite_kwh=>45293.93854982251,
            :exported_kwh=>1638.67781333994,
            :solar_pv_output_kwh=>46932.61636316246,
            :solar_pv_output_co2=>8884.491460063697,
            :old_mains_cost_£=>65366.193000000036,
            :new_mains_cost_£=>58265.917217496244,
            :export_income_£=>81.933890666997,
            :mains_savings_£=>7100.275782503792,
            :total_annual_saving_£=>7182.209673170789,
            :total_annual_saving_co2=>8884.491460063697,
            :capital_cost_£=>40811.633125,
            :payback_years=>5.682322708769174
          },
          { 
            :kwp=>64,
            :panels=>213,
            :area=>307,
            :existing_annual_kwh=>432245.09999999986,
            :existing_annual_£=>65366.193000000036,
            :new_mains_consumption_kwh=>379058.5446768536,
            :new_mains_consumption_£=>57031.63602275518,
            :reduction_in_mains_percent=>0.12304721400692871,
            :solar_consumed_onsite_kwh=>53186.555323147804,
            :exported_kwh=>4026.538910040475,
            :solar_pv_output_kwh=>57213.09423318829,
            :solar_pv_output_co2=>10830.61816083951,
            :old_mains_cost_£=>65366.193000000036,
            :new_mains_cost_£=>57031.63602275518,
            :export_income_£=>201.32694550202376,
            :mains_savings_£=>8334.556977244858,
            :total_annual_saving_£=>8535.883922746882,
            :total_annual_saving_co2=>10830.61816083951,
            :capital_cost_£=>48742.3488,
            :payback_years=>5.710287211159089
          },
          {
            :kwp=>128,
            :panels=>427,
            :area=>615,
            :existing_annual_kwh=>432245.09999999986,
            :existing_annual_£=>65366.193000000036,
            :new_mains_consumption_kwh=>347043.5680603858,
            :new_mains_consumption_£=>52039.81342698143,
            :reduction_in_mains_percent=>0.1971139335983544,
            :solar_consumed_onsite_kwh=>85201.53193961504,
            :exported_kwh=>29224.65652676189,
            :solar_pv_output_kwh=>114426.18846637658,
            :solar_pv_output_co2=>21661.23632167902,
            :old_mains_cost_£=>65366.193000000036,
            :new_mains_cost_£=>52039.81342698143,
            :export_income_£=>1461.2328263380946,
            :mains_savings_£=>13326.379573018603,
            :total_annual_saving_£=>14787.612399356698,
            :total_annual_saving_co2=>21661.23632167902,
            :capital_cost_£=>88555.3152,
            :payback_years=>5.9884796009295185
          }
        ]
      )
    end
  end
end
