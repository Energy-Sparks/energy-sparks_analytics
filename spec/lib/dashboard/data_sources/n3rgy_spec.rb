require 'date'
require 'json'
require 'faraday'
require 'logger'
require_relative '../../../../lib/dashboard/logging'
require_relative '../../../../lib/dashboard/data_sources/n3rgy'
require_relative '../../../../lib/dashboard/data_sources/n3rgy_raw'
require_relative '../../../../lib/dashboard/aggregation/amr_bad_data_types'
require_relative '../../../../lib/dashboard/aggregation/amr_one_days_data'

describe MeterReadingsFeeds::N3rgy do

  describe 'readings' do

    let(:mpxn)          { 1234567891234 }
    let(:fuel_type)     { :electricity }
    let(:start_date)    { Date.parse('20190101') }
    let(:end_date)      { Date.parse('20190102') }

    let(:raw_meter_readings_kwh)      { JSON.parse(File.read('spec/fixtures/n3rgy/raw_meter_readings_kwh.json')) }

    let(:expected_first_day_readings) { [1.449,0.671,1.212,1.208,0.972,0.445,0.43,0.35,0.388,0.366,0.449,0.374,0.381,0.412,0.464,0.38,0.317,0.313,0.488,0.529,1.96,0.839,0.554,1.062,1.635,0.734,0.561,0.518,0.407,0.362,0.291,0.28,0.349,0.32,0.415,0.355,0.318,0.321,0.347,0.409,0.406,0.354,0.362,0.311,0.439,0.439,0.38,0.39] }
    let(:expected_last_day_readings) { [0.426,0.405,0.479,0.463,0.528,0.517,0.589,0.554,0.599,0.595,0.648,0.574,0.674,0.633,0.713,0.585,0.562,0.481,0.516,0.459,0.473,0.399,0.459,0.462,0.496,0.51,0.478,0.369,0.482,0.433,0.416,0.403,0.451,0.406,0.386,0.417,0.4,0.377,0.532,0.637,0.688,0.736,0.643,0.621,0.642,0.791,1.331,0.512] }

    before do
      expect_any_instance_of(MeterReadingsFeeds::N3rgyRaw).to receive(:check_reading_types).exactly(2).times.and_return(true)
      expect_any_instance_of(MeterReadingsFeeds::N3rgyRaw).to receive(:meter_elements).and_return([1])
      expect_any_instance_of(MeterReadingsFeeds::N3rgyRaw).to receive(:raw_meter_readings_kwh).and_return(raw_meter_readings_kwh)
    end

    describe 'when successful' do

      it 'returns readings' do
        readings = MeterReadingsFeeds::N3rgy.new.readings(mpxn, fuel_type, start_date, end_date)
        expect(readings[fuel_type].keys).to match_array([:mpan_mprn, :readings, :missing_readings])

        expect(readings[fuel_type][:readings].count).to eq(2)
        expect(readings[fuel_type][:readings].keys).to eq([start_date, end_date])

        day_reading = readings[fuel_type][:readings][start_date]
        expect(day_reading.type).to eq('ORIG')
        expect(day_reading.kwh_data_x48).to eq(expected_first_day_readings)

        day_reading = readings[fuel_type][:readings][end_date]
        expect(day_reading.type).to eq('ORIG')
        expect(day_reading.kwh_data_x48).to eq(expected_last_day_readings)
      end

    end

  end
end
