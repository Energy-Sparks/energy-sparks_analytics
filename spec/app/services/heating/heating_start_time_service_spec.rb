require 'spec_helper'

describe Heating::HeatingStartTimeService, type: :service do

  let(:asof_date)      { Date.new(2022, 2, 1) }
  let(:service)        { Heating::HeatingStartTimeService.new(@acme_academy, asof_date)}

  #using before(:all) here to avoid slow loading of YAML and then
  #running the aggregation code for each test.
  before(:all) do
    @acme_academy = load_unvalidated_meter_collection(school: 'acme-academy')
  end

  context '#average_start_time_last_week' do
    it 'returns the expected data' do
      expect(service.average_start_time_last_week).to eq TimeOfDay.new(6,0)
    end
  end

  context '#calculate_start_times' do
    it 'returns the expected data' do
      start_times = service.last_week_start_times

      expect(start_times.average_start_time).to eq TimeOfDay.new(6,0)
      #returns the asof_date plus 7 days before
      expect(start_times.days.length).to eq 8

      first_day = start_times.days[0]
      expect(first_day.date).to eq Date.new(2022,1,25)
      expect(first_day.heating_start_time).to eq TimeOfDay.new(5,0)
      expect(first_day.recommended_time).to eq TimeOfDay.new(0,0)
      expect(first_day.temperature).to eq -0.3
      expect(first_day.saving.kwh).to eq 0
      expect(first_day.saving.£).to eq 0
      expect(first_day.saving.co2).to eq 0

      last_day = start_times.days.last
      expect(last_day.date).to eq Date.new(2022,2,1)
      expect(last_day.heating_start_time).to eq TimeOfDay.new(5,0)
      expect(last_day.recommended_time).to eq TimeOfDay.new(5,45)
      expect(last_day.temperature).to eq 8.5
      expect(last_day.saving.kwh).to round_to_two_digits(277.03)
      expect(last_day.saving.£).to round_to_two_digits(8.31)
      expect(last_day.saving.co2).to round_to_two_digits(58.18)

      # Tuesday 25 Jan 2022	05:00	00:00	-0.3C	on time	0	0p	0
      # Wednesday 26 Jan 2022	05:30	00:00	2.9C	on time	0	0p	0
      # Thursday 27 Jan 2022	05:30	06:17	9.6C	too early	290	£8.70	61
      # Friday 28 Jan 2022	06:00	03:45	4.5C	on time	0	0p	0
      # Saturday 29 Jan 2022			10.4C	no heating	0	0p	0
      # Sunday 30 Jan 2022			3.7C	no heating	0	0p	0
      # Monday 31 Jan 2022	03:00	04:27	5.9C	too early	490	£15	100
      # Tuesday 1 Feb 2022	05:00	05:45	8.5C	too early	280	£8.30	58

    end
  end

end
