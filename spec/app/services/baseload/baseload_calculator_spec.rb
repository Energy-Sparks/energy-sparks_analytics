require 'spec_helper'

describe Baseload::BaseloadCalculator, type: :service do
  let(:amr_data)        { create(:amr_data, :with_date_range) }

  context '.for_meter' do
    it 'returns calculator'
  end

  context '.calculator_for' do
    it 'returns calculator'
  end

  context '#average_baseload_kw_date_range' do
    subject(:calculator) { Baseload::StatisticalBaseloadCalculator.new(amr_data) }
    it 'calculates the average'
  end

  context '#baseload_kwh_date_range' do
    subject(:calculator) { Baseload::StatisticalBaseloadCalculator.new(amr_data) }
    it 'calculates the baseload'
  end
end
