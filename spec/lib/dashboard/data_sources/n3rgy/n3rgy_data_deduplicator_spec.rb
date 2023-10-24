# frozen_string_literal: true

require 'spec_helper'

describe MeterReadingsFeeds::N3rgyDataDeduplicator do
  let(:date1) { Date.parse('2012-02-01') }
  let(:date2) { date1 + 1 }
  let(:date3) { date1 + 2 }
  let(:date4) { date1 + 3 }
  let(:date5) { date1 + 4 }

  describe 'when deduplicating prices' do
    let(:usual_price)    { 0.15992 }
    let(:other_price)    { 0.1234 }

    let(:prices) do
      {
        date1 => usual_prices,
        date2 => usual_prices,
        date3 => other_prices,
        date4 => usual_prices,
        date5 => usual_prices
      }
    end

    let(:expected_deduped) do
      {
        date1 => usual_prices,
        date3 => other_prices,
        date4 => usual_prices,
        date5 => usual_prices
      }
    end

    describe 'with no data' do
      it 'returns empty hash' do
        deduped = described_class.deduplicate_prices({})
        expect(deduped).to eq({})
      end
    end

    describe 'with simple values' do
      let(:usual_prices)    { Array.new(48) { usual_price } }
      let(:other_prices)    { Array.new(48) { other_price } }

      it 'returns prices without duplicates but includng last date' do
        deduped = described_class.deduplicate_prices(prices)
        expect(deduped).to eq(expected_deduped)
      end
    end

    describe 'with complex values' do
      let(:usual_prices)    { Array.new(47) { usual_price } + [{ abc: 123, def: { xyz: TimeOfDay30mins.new(5, 30) } }] }
      let(:other_prices)    { Array.new(47) { usual_price } + [{ abc: 123, def: { xyz: TimeOfDay.new(5, 30) } }] }

      it 'returns prices without duplicates but includng last date' do
        deduped = described_class.deduplicate_prices(prices)
        expect(deduped).to eq(expected_deduped)
      end
    end
  end

  describe 'when deduplicating standing charges' do
    describe 'with no data' do
      it 'returns empty array' do
        deduped = described_class.deduplicate_standing_charges([])
        expect(deduped).to eq([])
      end
    end

    describe 'with simple values' do
      let(:usual_standing_charge)    { 0.555 }
      let(:other_standing_charge)    { 0.666 }

      let(:standing_charges) do
        [
          [date1, usual_standing_charge],
          [date2, usual_standing_charge],
          [date3, other_standing_charge],
          [date4, usual_standing_charge],
          [date5, usual_standing_charge]
        ]
      end

      let(:expected_deduped) do
        [
          [date1, usual_standing_charge],
          [date3, other_standing_charge],
          [date4, usual_standing_charge]
        ]
      end

      it 'returns standing charges without duplicates and NOT includng last date' do
        deduped = described_class.deduplicate_standing_charges(standing_charges)
        expect(deduped).to eq(expected_deduped)
      end
    end
  end
end
