# frozen_string_literal: true

require 'spec_helper'

describe AlertStorageHeaterHeatingOnDuringHoliday do
  subject(:alert) do
    described_class.new(meter_collection)
  end

  include_context 'with an aggregated meter with tariffs and school times' do
    let(:fuel_type) { :storage_heaters }
  end

  it_behaves_like 'a holiday usage alert'
end
