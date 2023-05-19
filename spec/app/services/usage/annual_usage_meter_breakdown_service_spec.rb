require 'spec_helper'

describe Usage::AnnualUsageMeterBreakdownService, type: :service do

  let(:asof_date)      { nil }
  let(:fuel_type)      { :electricity }
  let(:meter_collection) { @acme_academy }
  let(:service)        { Usage::AnnualUsageMeterBreakdownService.new(meter_collection, fuel_type, asof_date)}

  #using before(:all) here to avoid slow loading of YAML and then
  #running the aggregation code for each test.
  before(:all) do
    @acme_academy = load_unvalidated_meter_collection(school: 'acme-academy')
  end

  context '#calculate_breakdown' do
    def format_unit(unit, val)
      FormatEnergyUnit.format(unit, val, :html, true, true)
    end

    context 'for electricity' do
      context 'with two years data' do
        it 'calculates the expected values' do
          usage_breakdown = service.calculate_breakdown

          expect(usage_breakdown.start_date).to eq(Date.new(2021,7,11))
          expect(usage_breakdown.end_date).to eq(Date.new(2022,7,9))

          #Old Building
          # mpan 1591058886735
          percent = usage_breakdown.annual_percent_change(1591058886735)
          expect(format_unit(:relative_percent, percent)).to eq "+10%"
          old_building = usage_breakdown.usage(1591058886735)
          expect(format_unit(:kwh, old_building.kwh)).to eq "100,000"
          #expect(old_building.kwh).to round_to_two_digits(98392.4)
          expect(format_unit(:£, old_building.£)).to eq "&pound;15,000"
          expect(format_unit(:percent,old_building.percent)).to eq "21&percnt;"

          #New Building
          # mpan, 1580001320420
          percent = usage_breakdown.annual_percent_change(1580001320420)
          expect(format_unit(:relative_percent, percent)).to eq "+11%"
          new_building = usage_breakdown.usage(1580001320420)
          expect(format_unit(:kwh, new_building.kwh)).to eq "370,000"
          expect(format_unit(:£, new_building.£)).to eq "&pound;56,000"
          expect(format_unit(:percent,new_building.percent)).to eq "79&percnt;"

          #Total
          percent = usage_breakdown.total_annual_percent_change
          expect(format_unit(:relative_percent, percent)).to eq "+11%"
          total = usage_breakdown.total_usage
          expect(format_unit(:kwh, usage_breakdown.total_usage.kwh)).to eq "470,000"
          expect(format_unit(:£, usage_breakdown.total_usage.£)).to eq "&pound;71,000"
          expect(format_unit(:percent, usage_breakdown.total_usage.percent)).to eq "100&percnt;"
        end
      end
    end

    context 'for gas' do
      let(:fuel_type)      { :gas }
      context 'with two years data' do
        it 'calculates the expected values' do
          usage_breakdown = service.calculate_breakdown
          expect(usage_breakdown.start_date).to eq(Date.new(2021,7,11))
          expect(usage_breakdown.end_date).to eq(Date.new(2022,7,9))

          #Lodge
          percent = usage_breakdown.annual_percent_change(10307706)
          expect(format_unit(:relative_percent, percent)).to eq "+29%"
          meter = usage_breakdown.usage(10307706)
          expect(format_unit(:kwh, meter.kwh)).to eq "16,000"
          #expect(old_building.kwh).to round_to_two_digits(98392.4)
          expect(format_unit(:£, meter.£)).to eq "&pound;480"
          expect(format_unit(:percent,meter.percent)).to eq "2.8&percnt;"

          #Art Block
          percent = usage_breakdown.annual_percent_change(10308203)
          expect(format_unit(:relative_percent, percent)).to eq "-23%"
          meter = usage_breakdown.usage(10308203)
          expect(format_unit(:kwh, meter.kwh)).to eq "63,000"
          #expect(old_building.kwh).to round_to_two_digits(98392.4)
          expect(format_unit(:£, meter.£)).to eq "&pound;1,900"
          expect(format_unit(:percent,meter.percent)).to eq "11&percnt;"

          #Total
          percent = usage_breakdown.total_annual_percent_change
          expect(format_unit(:relative_percent, percent)).to eq "-19%"
          total = usage_breakdown.total_usage
          expect(format_unit(:kwh, usage_breakdown.total_usage.kwh)).to eq "580,000"
          expect(format_unit(:£, usage_breakdown.total_usage.£)).to eq "&pound;17,000"
          expect(format_unit(:percent, usage_breakdown.total_usage.percent)).to eq "100&percnt;"
        end
      end
    end
  end
end
