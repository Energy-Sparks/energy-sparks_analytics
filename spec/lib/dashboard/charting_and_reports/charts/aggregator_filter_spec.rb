# frozen_string_literal: true

require 'spec_helper'

describe AggregatorFilter do
  subject(:filter) do
    described_class.new(meter_collection, chart_config, aggregator_results)
  end

  let(:meter_collection) { instance_double(MeterCollection) }
  let(:aggregator_results) { AggregatorResults.new }
  let(:chart_config) do
    {
      name: 'Testing',
      meter_definition: :allelectricity,
      series_breakdown: :submeter,
      x_axis: :month,
      timescale: :up_to_a_year
    }
  end

  describe '#filter_series' do
    let(:bucketed_data) do
      {
        SolarPVPanels::ELECTRIC_CONSUMED_FROM_MAINS_METER_NAME => [],
        SolarPVPanels::SOLAR_PV_ONSITE_ELECTRIC_CONSUMPTION_METER_NAME => [],
        SolarPVPanels::SOLAR_PV_EXPORTED_ELECTRIC_METER_NAME => [],
        SolarPVPanels::SOLAR_PV_PRODUCTION_METER_NAME => []
      }
    end

    let(:aggregator_results) do
      results = AggregatorResults.new
      results.bucketed_data = bucketed_data
      results
    end

    context 'with no filter' do
      it 'does nothing' do
        filter.filter_series
        expect(aggregator_results.bucketed_data).to eq(bucketed_data)
      end
    end

    context 'with a submeter filter' do
      context 'when filtering solar submeters' do
        let(:chart_config) do
          {
            name: 'Testing',
            meter_definition: :allelectricity,
            series_breakdown: :submeter,
            x_axis: :month,
            timescale: :up_to_a_year,
            filter: {
              submeter: [
                SolarPVPanels::ELECTRIC_CONSUMED_FROM_MAINS_METER_NAME,
                SolarPVPanels::SOLAR_PV_EXPORTED_ELECTRIC_METER_NAME,
                SolarPVPanels::SOLAR_PV_ONSITE_ELECTRIC_CONSUMPTION_METER_NAME
              ]
            }
          }
        end

        it 'filters the submeter series and retains the y2 axis series' do
          filter.filter_series
          # should drop just the Solar PV production (:generation) meter
          expect(aggregator_results.bucketed_data.keys).to match_array(
            [
              SolarPVPanels::ELECTRIC_CONSUMED_FROM_MAINS_METER_NAME,
              SolarPVPanels::SOLAR_PV_EXPORTED_ELECTRIC_METER_NAME,
              SolarPVPanels::SOLAR_PV_ONSITE_ELECTRIC_CONSUMPTION_METER_NAME
            ]
          )
        end

        context 'with a solar irradiance y2 axis' do
          let(:chart_config) do
            {
              name: 'Testing',
              meter_definition: :allelectricity,
              series_breakdown: :submeter,
              x_axis: :month,
              timescale: :up_to_a_year,
              filter: {
                submeter: [
                  SolarPVPanels::ELECTRIC_CONSUMED_FROM_MAINS_METER_NAME,
                  SolarPVPanels::SOLAR_PV_EXPORTED_ELECTRIC_METER_NAME,
                  SolarPVPanels::SOLAR_PV_ONSITE_ELECTRIC_CONSUMPTION_METER_NAME
                ]
              },
              y2_axis: :irradiance
            }
          end

          let(:bucketed_data) do
            {
              SolarPVPanels::ELECTRIC_CONSUMED_FROM_MAINS_METER_NAME => [],
              SolarPVPanels::SOLAR_PV_ONSITE_ELECTRIC_CONSUMPTION_METER_NAME => [],
              SolarPVPanels::SOLAR_PV_EXPORTED_ELECTRIC_METER_NAME => [],
              SolarPVPanels::SOLAR_PV_PRODUCTION_METER_NAME => [],
              Series::Irradiance::IRRADIANCE => []
            }
          end

          it 'keeps that series as its not a submeter' do
            filter.filter_series
            # should drop just the Solar PV production (:generation) meters
            expect(aggregator_results.bucketed_data.keys).to match_array(
              [
                SolarPVPanels::ELECTRIC_CONSUMED_FROM_MAINS_METER_NAME,
                SolarPVPanels::SOLAR_PV_EXPORTED_ELECTRIC_METER_NAME,
                SolarPVPanels::SOLAR_PV_ONSITE_ELECTRIC_CONSUMPTION_METER_NAME,
                Series::Irradiance::IRRADIANCE
              ]
            )
          end
        end
      end
    end

    context 'with a heating filter' do
      let(:chart_config) do
        {
          name: 'Testing',
          meter_definition: :allheat,
          x_axis: :day,
          timescale: :up_to_a_year,
          series_breakdown: [:heating],
          filter: { heating: true }
        }
      end

      let(:bucketed_data) do
        {
          Series::HeatingNonHeating::HEATINGDAY => [],
          Series::HeatingNonHeating::NONHEATINGDAY => [],
          Series::HeatingNonHeating::HEATINGDAYWARMWEATHER => []
        }
      end

      it 'filters to just heating days' do
        filter.filter_series
        expect(aggregator_results.bucketed_data.keys).to match_array(
          [Series::HeatingNonHeating::HEATINGDAY]
        )
      end
    end

    context 'with a day type filter' do
      let(:chart_config) do
        {
          name: 'Testing',
          meter_definition: :allelectricity,
          x_axis: :intraday,
          timescale: :up_to_a_year,
          filter: {
            daytype: [Series::DayType::SCHOOLDAYOPEN, Series::DayType::SCHOOLDAYCLOSED]
          }
        }
      end

      let(:bucketed_data) do
        {
          Series::DayType::SCHOOLDAYOPEN => [],
          Series::DayType::SCHOOLDAYCLOSED => [],
          Series::DayType::WEEKEND => [],
          Series::DayType::HOLIDAY => []
        }
      end

      it 'filters to just those day types' do
        filter.filter_series
        expect(aggregator_results.bucketed_data.keys).to match_array(
          [Series::DayType::SCHOOLDAYOPEN, Series::DayType::SCHOOLDAYCLOSED]
        )
      end
    end
  end
end
