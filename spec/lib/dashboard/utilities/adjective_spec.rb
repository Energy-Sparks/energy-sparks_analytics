require 'spec_helper'

describe Adjective do

  context '#relative' do
    context 'with relative_to_1' do
      it 'returns the right values' do
        expect(Adjective.relative(-0.4, :relative_to_1)).to eq('significantly below')
        expect(Adjective.relative(-0.2, :relative_to_1)).to eq('below')
        expect(Adjective.relative(0.01, :relative_to_1)).to eq('about')
        expect(Adjective.relative(0.15, :relative_to_1)).to eq('above')
        expect(Adjective.relative(0.4, :relative_to_1)).to eq('significantly above')
      end
    end

    context 'with simple_relative_to_1' do
      it 'returns the right values' do
        expect(Adjective.relative(-0.4, :simple_relative_to_1)).to eq('below')
        expect(Adjective.relative(0.05, :simple_relative_to_1)).to eq('about')
        expect(Adjective.relative(0.4, :simple_relative_to_1)).to eq('above')
      end
    end

    context 'with custom hash' do
      let(:custom_ranges) {
        {
          -0.5..0.01 => :below,
          0.01..0.5 => :about,
          0.5..Float::INFINITY => :significantly_above
        }
      }
      it 'returns the right values' do
        expect(Adjective.relative(-0.4, custom_ranges)).to eq('below')
        expect(Adjective.relative(0.1, custom_ranges)).to eq('about')
        expect(Adjective.relative(0.6, custom_ranges)).to eq('significantly above')
      end
    end
  end

  context '#adjective_for' do
    it 'returns the right values' do
      expect(Adjective.adjective_for(1)).to eq "higher"
      expect(Adjective.adjective_for(-1)).to eq "lower"
    end
  end
end
