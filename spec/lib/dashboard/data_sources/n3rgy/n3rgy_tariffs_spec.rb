require 'spec_helper'

describe N3rgyTariffs do

  let(:subject) { N3rgyTariffs.new(tariff_data) }
  let(:tariff_data) { nil }

  describe '#parameterise' do

    context 'with empty data' do
      it 'returns nil' do
        expect( subject.parameterise ).to be_nil
      end

    end

    context 'with basic and tiered tariffs' do
      let(:start_date) { Date.parse("2012-04-26") }
      let(:end_date) { Date.parse("2012-04-27") }
      let(:single_day) { Date.parse("2012-04-28") }
      let(:single_day_tiered) { Date.parse("2012-04-29") }

      let(:early_range) { TimeOfDay30mins.new(0, 0)..TimeOfDay30mins.new(6, 30) }

      let(:tariff_data) { YAML.load_file('spec/fixtures/n3rgy/tariffs-basic-tiered.yaml') }

      let(:results) { subject.parameterise }

      context 'with kwh tariffs' do

        it 'returns kwh_rates' do
          expect(results[:kwh_rates]).to_not be_nil
        end

        it 'returns expected ranges' do
          expect(results[:kwh_rates][single_day..single_day]).to_not be_nil
          expect(results[:kwh_rates][start_date..end_date]).to_not be_nil
          expect(results[:kwh_rates][single_day_tiered..single_day_tiered]).to_not be_nil
        end

        it 'summarises basic tariffs by day' do
          tariffs = results[:kwh_rates][single_day..single_day]
          expect( tariffs[early_range]).to eq(0.0978)
        end

        it 'groups days' do
          tariffs = results[:kwh_rates][start_date..end_date]
          expect( tariffs[early_range]).to eq(0.0878)
        end

        it 'summarises tiered tariffs' do
          tariffs = results[:kwh_rates][single_day_tiered..single_day_tiered]
          range = TimeOfDay30mins.new(0, 0)..TimeOfDay30mins.new(7, 30)
          expect( tariffs[range] ).to eq(0.4385)
          tiered_range = TimeOfDay30mins.new(8, 0)..TimeOfDay30mins.new(19, 30)
          expect( tariffs[tiered_range][0.0..1000.0] ).to eq(0.48527)
          expect( tariffs[tiered_range][1000.0..Float::INFINITY] ).to eq(0.16774)
        end

      end

      context 'with standing charges' do

        it 'returns standing changes' do
          expect(results[:standing_charges]).to_not be_nil
        end

        it 'summarises standing charges' do
          expect(results[:standing_charges][start_date..N3rgyTariffs::INFINITE_DATE]).to eql(0.0025)
        end
      end

    end

    describe 'with Weekday Tariffs' do
      let(:tariff_data) { YAML.load_file('spec/fixtures/n3rgy/tariffs-weekday.yaml') }

      let(:weekend_start_date) { Date.parse("2012-05-12")}
      let(:weekend_end_date) { Date.parse("2014-02-23")}

      let(:weekday_start_date) { Date.parse("2012-05-14")}
      let(:weekday_end_date) { Date.parse("2014-02-28")}

      let(:results) { subject.parameterise }

      it 'should group them correctly' do
        #TODO check with Philip as the return value changes to an array here...?
        range = weekend_start_date..weekend_end_date
        tariffs = results[:kwh_rates][1][range]

        until_seven = TimeOfDay30mins.new(0, 0)..TimeOfDay30mins.new(6, 30)
        from_seven = TimeOfDay30mins.new(7, 0)..TimeOfDay30mins.new(23, 30)

        expect( tariffs[until_seven] ).to eql(0.0641)
        expect( tariffs[from_seven] ).to eql(0.1402)
        expect( tariffs[:weekdays] ).to match_array [0, 6]

        seven_to_four = TimeOfDay30mins.new(7, 0)..TimeOfDay30mins.new(15, 30)
        four_to_eight = TimeOfDay30mins.new(16, 0)..TimeOfDay30mins.new(19, 30)
        eight_to_midnight = TimeOfDay30mins.new(20, 0)..TimeOfDay30mins.new(23, 30)

        tariffs = results[:kwh_rates][2][weekday_start_date..weekday_end_date]

        expect( tariffs[until_seven] ).to eql(0.0641)
        expect( tariffs[seven_to_four] ).to eql(0.1402)
        expect( tariffs[four_to_eight] ).to eql(0.2999)
        expect( tariffs[eight_to_midnight]).to eql(0.1402)

        expect( tariffs[:weekdays] ).to match_array [1, 2, 3, 4, 5]
      end
    end

    # describe 'tariff switching' do
    #   let(:first_tariff_data) { YAML.load_file('spec/fixtures/n3rgy/tariffs-basic-tiered.yaml') }
    #   let(:second_tariff_data) { YAML.load_file('spec/fixtures/n3rgy/tariffs-weekday.yaml') }
    #
    #   let(:tariff_data) {
    #     {
    #       kwh_tariffs: first_tariff_data[:kwh_tariffs].merge(second_tariff_data[:kwh_tariffs]),
    #       standing_charges: first_tariff_data[:standing_charges].merge(second_tariff_data[:standing_charges])
    #     }
    #   }
    #   let(:results) { subject.parameterise }
    #
    #   it 'handles a switch' do
    #     puts results.inspect
    #   end
    # end
  end

end
