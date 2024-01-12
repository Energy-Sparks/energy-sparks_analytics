# frozen_string_literal: true

require 'spec_helper'

describe Holidays do
  describe '.periods_cadence' do
    let(:include_partial_period) { false }
    let(:move_to_saturday_boundary) { false }
    let(:minimum_days) { nil }

    let(:periods) do
      Holidays.periods_cadence(
        start_date,
        end_date,
        include_partial_period: include_partial_period,
        move_to_saturday_boundary: move_to_saturday_boundary,
        minimum_days: minimum_days
      )
    end

    let(:end_date) { Date.new(2024, 1, 1) }

    context 'with less than a year' do
      let(:start_date) { end_date - 30 }

      it 'returns single period' do
        expect(periods.length).to eq 0
      end
    end

    context 'with 364 days' do
      let(:start_date) { end_date - 363 }

      it 'returns single period' do
        expect(periods.length).to eq 1
      end

      context 'when partial periods allowed' do
        let(:include_partial_period) { true }

        it 'returns single periods' do
          expect(periods.length).to eq 1
        end
      end
    end

    context 'with 365 days' do
      let(:start_date) { end_date - 364 }

      it 'returns single period' do
        expect(periods.length).to eq 1
      end

      context 'when partial periods allowed' do
        let(:include_partial_period) { true }

        it 'returns two periods' do
          expect(periods.length).to eq 2
        end

        context 'with minimum days per period' do
          let(:minimum_days) { 7 }

          it 'returns a single period' do
            expect(periods.length).to eq 1
          end
        end
      end
    end

    context 'with 2 years' do
      let(:start_date) { end_date - 364 * 2.0 }

      it 'returns 2 periods' do
        expect(periods.length).to eq 2
      end
    end
  end
end
