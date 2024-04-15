# frozen_string_literal: true

require 'spec_helper'

describe AlertGasHeatingHotWaterOnDuringHoliday do
  subject(:alert) do
    described_class.new(meter_collection)
  end

  include_context 'with an aggregated meter with tariffs and school times' do
    let(:fuel_type) { :gas }
  end

  it_behaves_like 'a holiday usage alert'
end
