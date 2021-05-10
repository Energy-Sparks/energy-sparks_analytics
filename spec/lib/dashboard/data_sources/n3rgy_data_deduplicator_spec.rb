require 'spec_helper'

describe MeterReadingsFeeds::N3rgyDataDeduplicator do

  let(:date_1) { Date.parse('2012-02-01') }
  let(:date_2) { date_1 + 1 }
  let(:date_3) { date_1 + 2 }
  let(:date_4) { date_1 + 3 }
  let(:date_5) { date_1 + 4 }

  describe 'when deduplicating prices' do

    let(:usual_price)    { 0.15992 }
    let(:other_price)    { 0.1234 }

    let(:prices) do
      {
        date_1 => usual_prices,
        date_2 => usual_prices,
        date_3 => other_prices,
        date_4 => usual_prices,
        date_5 => usual_prices,
      }
    end

    let(:expected_deduped) do
      {
        date_1 => usual_prices,
        date_3 => other_prices,
        date_4 => usual_prices,
        date_5 => usual_prices,
      }
    end

    describe 'with simple values' do

      let(:usual_prices)    { Array.new(48) { usual_price } }
      let(:other_prices)    { Array.new(48) { other_price } }

      it 'returns prices without duplicates but includng last date' do
        deduped = MeterReadingsFeeds::N3rgyDataDeduplicator.deduplicate_prices(prices)
        expect(deduped).to eq(expected_deduped)
      end
    end

    describe 'with complex values' do

      let(:usual_prices)    { Array.new(47) { usual_price } + [{abc: 123, def: {xyz: TimeOfDay30mins.new(5, 30)}}] }
      let(:other_prices)    { Array.new(47) { usual_price } + [{abc: 123, def: {xyz: TimeOfDay.new(5, 30)}}] }

      it 'returns prices without duplicates but includng last date' do
        deduped = MeterReadingsFeeds::N3rgyDataDeduplicator.deduplicate_prices(prices)
        expect(deduped).to eq(expected_deduped)
      end
    end
  end

  describe 'when deduplicating standing charges' do

    describe 'with simple values' do

      let(:usual_standing_charge)    { 0.555 }
      let(:other_standing_charge)    { 0.666 }

      let(:standing_charges) do
        [
          [date_1, usual_standing_charge],
          [date_2, usual_standing_charge],
          [date_3, other_standing_charge],
          [date_4, usual_standing_charge],
          [date_5, usual_standing_charge],
        ]
      end

      let(:expected_deduped) do
        [
          [date_1, usual_standing_charge],
          [date_3, other_standing_charge],
          [date_4, usual_standing_charge],
        ]
      end

      it 'returns standing charges without duplicates and NOT includng last date' do
        deduped = MeterReadingsFeeds::N3rgyDataDeduplicator.deduplicate_standing_charges(standing_charges)
        expect(deduped).to eq(expected_deduped)
      end

      it 'returns empty array if no standing charges' do
        deduped = MeterReadingsFeeds::N3rgyDataDeduplicator.deduplicate_standing_charges([])
        expect(deduped).to eq([])
      end
    end
  end
end
