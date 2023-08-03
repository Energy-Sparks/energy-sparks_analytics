require 'spec_helper'

describe DateTimeHelper do

  describe '#weighted_x48_vector_multiple_ranges' do

    context 'with single range' do
      let(:range) { [TimeOfDay.new(8,50)..TimeOfDay.new(15,20)] }
      it 'returns expected values' do
        vector = DateTimeHelper.weighted_x48_vector_multiple_ranges(range)
        expect(vector[0..16]).to eq Array.new(17,0.0)
        expect(vector[17]).to eq 0.6666666666666666
        expect(vector[18..29]).to eq Array.new(12,1.0)
        expect(vector[30]).to eq 0.6666666666666666
        expect(vector[31..48]).to eq Array.new(17,0.0)
      end
    end

    context 'with multiple ranges' do
      let(:range) { [TimeOfDay.new(15,21)..TimeOfDay.new(19,30), TimeOfDay.new(7,0)..TimeOfDay.new(8,49)] }
      it 'returns expected values' do
        vector = DateTimeHelper.weighted_x48_vector_multiple_ranges(range)
        expect(vector[0..13]).to eq Array.new(14,0.0)
        #14 == 7am
        #16 == 8am
        expect(vector[14..16]).to eq Array.new(3, 1.0)
        #17 == 8.30am, 19 / 30 minutes (% time through hh slot)
        expect(vector[17]).to eq 0.6333333333333333
        #19 == 9.00am
        expect(vector[18..29]).to eq Array.new(12,0.0)
        #30 == 15.00, 21 / 30 minutes (% time through hh slot)
        expect(vector[30]).to eq 0.7
        expect(vector[31..38]).to eq Array.new(8,1.0)
        expect(vector[39..48]).to eq Array.new(9,0.0)
      end
    end

  end

  describe '#weighted_x48_vector_single_range' do
    let(:range) { TimeOfDay.new(0,0)..TimeOfDay.new(1,0) }

    it 'returns expected weights' do
      expect(DateTimeHelper.weighted_x48_vector_single_range(range)).to eq([1.0, 1.0] + Array.new(46, 0.0))
    end

    context 'with mid day' do
      let(:range) { TimeOfDay.new(8,0)..TimeOfDay.new(10,0) }

      it 'returns expected weights' do
        expect(DateTimeHelper.weighted_x48_vector_single_range(range)).to eq( Array.new(16, 0.0) + Array.new(4, 1.0) + Array.new(28, 0.0) )
      end
    end

    context 'with full day' do
      let(:range) { TimeOfDay.new(0,0)..TimeOfDay.new(24,00) }

      it 'returns expected weights' do
        expect(DateTimeHelper.weighted_x48_vector_single_range(range)).to eq(Array.new(48, 1.0))
      end
    end
  end

  describe '#weighted_x48_vector_fast_inclusive' do
    let(:range)  { TimeOfDay.new(0,0)..TimeOfDay.new(1,0) }
    let(:weight) { 1.0 }
    it 'returns expected weights' do
      expect(DateTimeHelper.weighted_x48_vector_fast_inclusive(range, weight)).to eq([1.0, 1.0, 1.0] + Array.new(45, 0.0))
    end

    context 'with mid day' do
      let(:range) { TimeOfDay.new(8,0)..TimeOfDay.new(10,0) }

      it 'returns expected weights' do
        expect(DateTimeHelper.weighted_x48_vector_fast_inclusive(range, weight)).to eq( Array.new(16, 0.0) + Array.new(5, 1.0) + Array.new(27, 0.0) )
      end
    end

    context 'with range ending 23:30' do
      let(:range) { TimeOfDay.new(0,0)..TimeOfDay.new(23,30) }

      it 'returns expected weights' do
        expect(DateTimeHelper.weighted_x48_vector_fast_inclusive(range, weight)).to eq(Array.new(48, 1.0))
      end
    end

    context 'with overnight range' do
      let(:range) { TimeOfDay.new(23,0)..TimeOfDay.new(1,0) }

      it 'returns expected weights' do
        expect(DateTimeHelper.weighted_x48_vector_fast_inclusive(range, weight)).to eq(Array.new(3,1.0) + Array.new(43, 0.0) + Array.new(2, 1.0))
      end
    end

  end
end
