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
    let(:start_date)    { Date.parse('20210127') }
    let(:end_date)      { Date.parse('20210128') }

    let(:raw_meter_readings_kwh)      { JSON.parse(File.read('spec/fixtures/n3rgy/raw_meter_readings_kwh.json')) }

    before do
      expect_any_instance_of(MeterReadingsFeeds::N3rgyRaw).to receive(:check_reading_types).exactly(2).times.and_return(true)
      expect_any_instance_of(MeterReadingsFeeds::N3rgyRaw).to receive(:meter_elements).and_return([1])
      expect_any_instance_of(MeterReadingsFeeds::N3rgyRaw).to receive(:raw_meter_readings_kwh).and_return(raw_meter_readings_kwh)
    end

    describe 'when successful' do

      it 'returns readings' do
        readings = MeterReadingsFeeds::N3rgy.new.readings(mpxn, fuel_type, start_date, end_date)
        expect(readings[fuel_type].keys).to match_array([:mpan_mprn, :readings, :missing_readings])

        puts readings[fuel_type][:readings]

        expect(readings[fuel_type][:readings].count).to eq(2)
        expect(readings[fuel_type][:readings][start_date].type).to eq('ORIG')
        expect(readings[fuel_type][:readings][end_date].type).to eq('ORIG')
      end

    end

  end
end
