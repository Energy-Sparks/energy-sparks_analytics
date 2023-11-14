# frozen_string_literal: true

require 'spec_helper'

describe N3rgyToEnergySparksTariffs do
  let(:subject) { described_class.new(tariff_data) }
  let(:tariff_data) { nil }

  describe '#convert' do
    let(:day) { Date.parse('2012-04-28') }
    let(:day_range) { day..day }
    let(:charge_day_range) { day..N3rgyTariffs::INFINITE_DATE }

    let(:early_tariff_range) { TimeOfDay30mins.new(0, 0)..TimeOfDay30mins.new(6, 30) }
    let(:later_tariff_range) { TimeOfDay30mins.new(7, 0)..TimeOfDay30mins.new(23, 30) }

    let(:results) { subject.convert }

    it 'ignores empty tariffs' do
      expect(results).to be_nil
    end

    context 'with flat tariffs' do
      let(:full_day) { TimeOfDay30mins.new(0, 0)..TimeOfDay30mins.new(23, 30) }
      let(:tariff_data) do
        {
          kwh_rates: {
            day_range => {
              full_day => 0.1
            }
          },
          standing_charges: {
            charge_day_range => 0.05
          }
        }
      end

      it 'generates a flat tariff' do
        expect(results[:accounting_tariff_generic]).to eql(
          [{
            start_date: day,
            end_date: day,
            name: 'Tariff from DCC SMETS2 meter',
            tariff_holder: :meter,
            rates: {
              flat_rate: {
                per: :kwh,
                rate: 0.1
              },
              standing_charge: {
                per: :day,
                rate: 0.05
              }
            },
            type: :flat_rate,
            source: :dcc
          }]
        )
      end
    end

    context 'with simple tariffs' do
      let(:tariff_data) do
        {
          kwh_rates: {
            day_range => {
              early_tariff_range => 0.1,
              later_tariff_range => 0.2
            }
          },
          standing_charges: {
            charge_day_range => 0.05
          }
        }
      end

      let(:results) { subject.convert }

      it 'generates a differential tariff' do
        expect(results[:accounting_tariff_generic]).to eql(
          [{
            start_date: day,
            end_date: day,
            name: 'Tariff from DCC SMETS2 meter',
            tariff_holder: :meter,
            rates: {
              rate0: {
                from: TimeOfDay30mins.new(0, 0),
                to: TimeOfDay30mins.new(6, 30),
                per: :kwh,
                rate: 0.1
              },
              rate1: {
                from: TimeOfDay30mins.new(7, 0),
                to: TimeOfDay30mins.new(23, 30),
                per: :kwh,
                rate: 0.2
              },
              standing_charge: {
                per: :day,
                rate: 0.05
              }
            },
            type: :differential,
            source: :dcc
          }]
        )
      end
    end

    context 'with tiered tariffs' do
      let(:tariff_data) do
        {
          kwh_rates: {
            day_range => {
              early_tariff_range => 0.1,
              later_tariff_range => {
                0.0..1000.0 => 0.1,
                1000.0..Float::INFINITY => 0.2
              }
            }
          },
          standing_charges: {
            charge_day_range => 0.05
          }
        }
      end

      it 'generates a tiered tariff' do
        expect(results[:accounting_tariff_generic]).to eql(
          [{
            start_date: day,
            end_date: day,
            name: 'Tariff from DCC SMETS2 meter',
            tariff_holder: :meter,
            rates: {
              rate0: {
                from: TimeOfDay30mins.new(0, 0),
                to: TimeOfDay30mins.new(6, 30),
                per: :kwh,
                rate: 0.1
              },
              tiered_rate1: {
                from: TimeOfDay30mins.new(7, 0),
                to: TimeOfDay30mins.new(23, 30),
                tier0: { low_threshold: 0.0, high_threshold: 1000.0, rate: 0.1 },
                tier1: { low_threshold: 1000.0, high_threshold: Float::INFINITY, rate: 0.2 },
                per: :kwh
              },
              standing_charge: {
                per: :day,
                rate: 0.05
              }
            },
            type: :differential_tiered,
            source: :dcc
          }]
        )
      end
    end

    context 'with weekday tariffs' do
      let(:tariff_data) do
        {
          kwh_rates: [{
            day_range => {
              early_tariff_range => 0.1,
              later_tariff_range => 0.2,
              weekdays: [1, 2, 3, 4, 5]
            }
          }],
          standing_charges: {
            charge_day_range => 0.05
          }
        }
      end

      it 'generates a weekday tariff' do
        expect(results[:accounting_tariff_generic]).to eql(
          [{
            start_date: day,
            end_date: day,
            name: 'Tariff from DCC SMETS2 meter',
            tariff_holder: :meter,
            rates: {
              rate0: {
                from: TimeOfDay30mins.new(0, 0),
                to: TimeOfDay30mins.new(6, 30),
                per: :kwh,
                rate: 0.1
              },
              rate1: {
                from: TimeOfDay30mins.new(7, 0),
                to: TimeOfDay30mins.new(23, 30),
                per: :kwh,
                rate: 0.2
              },
              standing_charge: {
                per: :day,
                rate: 0.05
              }
            },
            type: :differential,
            sub_type: :weekday_weekend,
            weekday: true,
            source: :dcc
          }]
        )
      end
    end
  end
end
