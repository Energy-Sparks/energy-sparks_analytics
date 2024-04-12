# frozen_string_literal: true

require 'spec_helper'

describe AlertElectricityUsageDuringCurrentHoliday do
  subject(:alert) do
    described_class.new(meter_collection)
  end

  let(:fuel_type) { :electricity }

  # AMR data for the school
  # For testing the basic calculations we just use flat usage, carbon intensity
  # profile and flat tariff rates
  let(:usage_per_hh)      { 10.0 }
  let(:carbon_intensity)  { 0.2 }
  let(:flat_rate)         { 0.10 }

  let(:amr_start_date)  { Date.new(2023, 12, 1) }
  let(:amr_end_date)    { Date.new(2023, 12, 31) }

  let(:amr_data) do
    build(:amr_data, :with_date_range, :with_grid_carbon_intensity, grid_carbon_intensity: grid_carbon_intensity, start_date: amr_start_date, end_date: amr_end_date, kwh_data_x48: Array.new(48) { usage_per_hh })
  end

  # Carbon intensity used to calculate co2 emissions
  let(:grid_carbon_intensity) { build(:grid_carbon_intensity, :with_days, start_date: amr_start_date, end_date: amr_end_date, kwh_data_x48: Array.new(48) { carbon_intensity }) }

  let(:aggregate_meter) do
    build(:meter, :with_flat_rate_tariffs, type: fuel_type, amr_data: amr_data, tariff_start_date: amr_start_date, tariff_end_date: amr_end_date, rates: create_flat_rate(rate: flat_rate))
  end

  # Xmas holiday from 2023-12-16 to 2024-1-1, which is 11 weekdays during
  # the default period defined by amr_start_date and amr_end_date
  let(:holidays) { build(:holidays, :with_calendar_year, year: 2023) }

  # primary school, with 1000 pupils and 5000 sq m2 by default
  let(:meter_collection) { build(:meter_collection, holidays: holidays) }

  let(:asof_date) { Date.new(2023, 12, 23) }
  let(:today)     { asof_date.iso8601 }

  # Configure objects as if we've run the aggregation process
  before do
    meter_collection.set_aggregate_meter(fuel_type, aggregate_meter)
    aggregate_meter.set_tariffs
  end

  # The alert checks the current date, but has option to override via
  # an environment variable. So by default set it as if we're running
  # on the asof_date
  around do |example|
    ClimateControl.modify ENERGYSPARKSTODAY: today do
      example.run
    end
  end

  describe '#enough_data?' do
    context 'with enough data' do
      it 'returns :enough' do
        expect(alert.enough_data).to eq(:enough)
      end
    end

    context 'when outside holiday' do
      let(:asof_date) { Date.new(2023, 12, 15) }

      it 'returns :not_enough' do
        expect(alert.enough_data).to eq(:not_enough)
      end
    end

    context 'when data doesnt cover holiday' do
      let(:amr_end_date) { Date.new(2023, 12, 10) }
      let(:asof_date) { Date.new(2023, 12, 15) }

      it 'returns :not_enough' do
        expect(alert.enough_data).to eq(:not_enough)
      end
    end
  end

  describe '#analyse' do
    before do
      alert.analyse(asof_date)
    end

    context 'when 1 week into a holiday' do
      # 7 days from 16th December to 23rd December
      let(:asof_date) { Date.new(2023, 12, 22) }

      it 'calculates rating' do
        expect(alert.rating).to eq(0.0)
      end

      it 'calculates expected usage' do
        # usage_per_hh * 48 * 7 days
        expect(alert.holiday_usage_to_date_kwh).to eq(3360.0)
        # flat_rate tariff * kwh above
        expect(alert.holiday_usage_to_date_£).to eq(336.0)
        # carbon_intensity * kwh above
        expect(alert.holiday_usage_to_date_co2).to eq(672.0)
      end

      it 'calculates expected projection' do
        # usage_per_hh * 48 * 17 days
        expect(alert.holiday_projected_usage_kwh).to eq(8160.0)
        expect(alert.holiday_projected_usage_£).to eq(816.0)
        expect(alert.holiday_projected_usage_co2).to eq(1632.0)
      end
    end

    context 'with 2 weekend days into a holiday' do
      # 2 days from 16th December to 17th December
      let(:asof_date) { Date.new(2023, 12, 17) }

      it 'calculates rating' do
        expect(alert.rating).to eq(0.0)
      end

      it 'calculates expected usage' do
        # usage_per_hh * 48 * 2 days
        expect(alert.holiday_usage_to_date_kwh).to eq(960.0)
        # flat_rate tariff * kwh above
        expect(alert.holiday_usage_to_date_£).to eq(96.0)
        # carbon_intensity * kwh above
        expect(alert.holiday_usage_to_date_co2).to eq(192.0)
      end

      it 'calculates expected projection' do
        # usage_per_hh * 48 * 17 days
        # confirms that weekend usage is substituted for weekday
        # when we don't have additional data
        expect(alert.holiday_projected_usage_kwh).to eq(8160.0)
        expect(alert.holiday_projected_usage_£).to eq(816.0)
        expect(alert.holiday_projected_usage_co2).to eq(1632.0)
      end
    end
  end
end
