require 'spec_helper'

describe Baseload::StatisticalBaseloadCalculator, type: :service do
  let(:start_date)      { Date.new(2023,1,1) }
  let(:end_date)        { Date.new(2023,1,31) }
  let(:amr_data)        { create(:amr_data, :with_date_range, start_date: start_date, end_date: end_date) }

  subject(:calculator) { Baseload::StatisticalBaseloadCalculator.new(amr_data) }

  context '#baseload_kw' do
    it 'calculates the baseload for a day'

    context 'for a day not in the data' do
      it 'raises an exception'
    end
  end

end
