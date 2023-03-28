require 'spec_helper'

describe Usage::HolidayUsageCalculationService, type: :service do

  let(:fuel_type)        { :electricity }
  let(:meter_collection) { @acme_academy }
  let(:meter)            { meter_collection.aggregated_electricity_meters }
  let(:asof_date)        { Date.today }
  let(:service)          { Usage::HolidayUsageCalculationService.new(meter, meter_collection.holidays, asof_date)}

  #using before(:all) here to avoid slow loading of YAML and then
  #running the aggregation code for each test.
  before(:all) do
    @acme_academy = load_unvalidated_meter_collection(school: 'acme-academy')
  end

  context 'with electricity meters' do
    context '#holiday_usage' do
      let(:academic_year) { nil }
      let(:school_period) { Holiday.new(holiday_type, name, start_date, end_date, academic_year) }
      let(:usage) { service.holiday_usage(school_period: school_period) }

      context 'for xmas 2021/2022' do
        let(:holiday_type)  { :xmas }
        let(:name)          { "Xmas 2021/2022" }
        let(:start_date)    { Date.new(2021,12,18)}
        #last day of xmas holiday
        let(:end_date)      { Date.new(2022,01,3) }

        it 'calculates the expected usage' do
          expect(usage.kwh).to be_within(0.1).of(10425.6)
          expect(usage.co2).to be_within(0.1).of(1794.7996)
          expect(usage.£).to be_within(0.1).of(1558.438)
        end
      end

      context 'for xmas 2020/2021' do
        let(:holiday_type)  { :xmas }
        let(:name)          { "Xmas 2020/2021" }
        let(:start_date)    { Date.new(2020,12,19)}
        #last day of xmas holiday
        let(:end_date)      { Date.new(2021,1,3) }

        it 'calculates the expected usage' do
          expect(usage.kwh).to be_within(0.1).of(11728.89)
          expect(usage.co2).to be_within(0.1).of(2068.9643)
          expect(usage.£).to be_within(0.1).of(1754.026)
        end
      end

      context 'for autumn half term 2021' do
        let(:holiday_type)  { :autumn_half_term }
        let(:name)          { "Autumn half term" }
        let(:start_date)    { Date.new(2021,10,23) }
        let(:end_date)      { Date.new(2021,10,31) }

        it 'calculates the expected usage' do
          expect(usage.kwh).to be_within(0.1).of(7801.6)
          expect(usage.co2).to be_within(0.1).of(979.229)
          expect(usage.£).to be_within(0.1).of(1181.78)
        end
      end

      context 'for period outside meter range' do
        let(:holiday_type)  { :summer }
        let(:name)          { "Summer 2022" }
        let(:start_date)    { Date.new(2022,7,14) }
        let(:end_date)      { Date.new(2022,8,31) }
        it 'returns nil' do
          expect(usage).to eq nil
        end
      end

      context 'in the middle of a holiday' do
        let(:holiday_type)  { :xmas }
        let(:name)          { "Xmas 2021/2022" }
        let(:start_date)    { Date.new(2021,12,18)}
        #last day of xmas holiday
        let(:end_date)      { Date.new(2022,01,3) }
        let(:asof_date)     { Date.new(2021,12,25) }

        it 'returns partial usage' do
          #less than usage for full holiday
          expect(usage.kwh).to be <= 10425.6
        end

      end
    end

    context '#holiday_usage_comparison' do
      let(:academic_year) { nil }
      let(:school_period) { Holiday.new(holiday_type, name, start_date, end_date, academic_year) }
      let(:comparison) { service.holiday_usage_comparison(school_period: school_period) }

      context 'for xmas 2021/2022' do
        let(:holiday_type)  { :xmas }
        let(:name)          { "Xmas" }
        let(:start_date)    { Date.new(2021,12,18)}
        let(:end_date)      { Date.new(2022,01,3) }

        it 'produces the right comparison' do
          xmas_2021_usage = comparison.usage
          expect(xmas_2021_usage.kwh).to be_within(0.1).of(10425.6)
          expect(xmas_2021_usage.co2).to be_within(0.1).of(1794.7996)
          expect(xmas_2021_usage.£).to be_within(0.1).of(1558.438)

          expect(comparison.previous_holiday).to_not be_nil

          xmas_2020_usage = comparison.previous_holiday_usage
          expect(xmas_2020_usage.kwh).to be_within(0.1).of(11728.89)
          expect(xmas_2020_usage.co2).to be_within(0.1).of(2068.9643)
          expect(xmas_2020_usage.£).to be_within(0.1).of(1754.026)
        end
      end

      context 'for period outside meter range' do
        let(:holiday_type)  { :easter }
        let(:name)          { "Easter 2019" }
        let(:start_date)    { Date.new(2019,4,13)}
        let(:end_date)      { Date.new(2019,4,28) }

        it 'returns nil for previous year' do
          expect(comparison.usage).to_not be_nil
          expect(comparison.previous_holiday_usage).to be_nil
        end
      end
    end

    context '#holidays_usage_comparison' do
      let(:academic_year) { nil }
      let(:school_period_1) { Holiday.new(:xmas, "Xmas 2021/2022", Date.new(2021,12,18), Date.new(2022,01,3), academic_year) }
      let(:school_period_2) { Holiday.new(:autumn_half_term, "Autum half term", Date.new(2021,10,23), Date.new(2021,10,31), academic_year) }
      let(:comparison) { service.holidays_usage_comparison(school_periods: [school_period_1, school_period_2]) }

      it 'calculates all comparisons' do
        expect(comparison[school_period_1]).to_not be_nil
        expect(comparison[school_period_2]).to_not be_nil
      end
    end

    context '#school_holiday_calendar_comparison' do

      context 'for Easter 2022' do
        let(:asof_date)        { Date.new(2022, 4, 1) }
        let(:holiday_comparison) { service.school_holiday_calendar_comparison }

        it 'finds all the holidays' do
          holiday_types = holiday_comparison.keys.map {|h| h.type }
          expect(holiday_types).to match_array([:autumn_half_term, :xmas, :spring_half_term, :easter, :summer_half_term, :summer])
        end

        it 'calculates usage for all holidays' do
          holiday_comparison.each do |holiday, usage|
            expect(usage.usage).to_not be_nil
          end
        end

        it 'has Easter as latest' do
          latest_holiday = holiday_comparison.keys.sort{|a,b| b.start_date <=> a.start_date }.last
          expect(latest_holiday.type).to eq :easter
        end
      end

      context 'for Summer 2022' do
        #last meter date
        let(:asof_date)        { Date.new(2022,7,13) }
        let(:service)          { Usage::HolidayUsageCalculationService.new(meter, meter_collection.holidays, asof_date)}
        let(:holiday_comparison) { service.school_holiday_calendar_comparison }

        it 'finds all the holidays' do
          holiday_types = holiday_comparison.keys.map {|h| h.type }
          expect(holiday_types).to match_array([:autumn_half_term, :xmas, :spring_half_term, :easter, :summer_half_term, :summer])
        end

        it 'calculates usage for all holidays' do
          holiday_comparison.each do |holiday, usage|
            expect(usage.usage).to_not be_nil
          end
        end

        it 'has Summer as latest' do
          latest_holiday = holiday_comparison.keys.sort{|a,b| b.start_date <=> a.start_date }.last
          expect(latest_holiday.type).to eq :summer
        end

      end
    end

  end
end
