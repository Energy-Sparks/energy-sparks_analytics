# frozen_string_literal: true

require 'spec_helper'
require 'active_support/core_ext'

describe Benchmarking::BenchmarkContentEnergyPerFloorArea, type: :service do
  let(:benchmark) do
    Benchmarking::BenchmarkContentEnergyPerFloorArea.new(
      benchmark_database_hash,
      benchmark_database_hash.keys.first,
      :annual_energy_costs_per_floor_area,
      Benchmarking::BenchmarkManager::CHART_TABLE_CONFIG[:annual_energy_costs_per_floor_area]
    )
  end

  describe '#content_title' do
    it 'returns the content title' do
      html = benchmark.send(:content_title)
      expect(html).to match_html(<<~HTML)
        <h1>
          Annual energy use per floor area
        </h1>
      HTML
    end
  end

  describe 'introduction_text' do
    it 'formats introduction and any caveat text as html' do
      html = benchmark.send(:introduction_text)
      expect(html).to match_html(<<~HTML)
        <p>
          <p>
            This comparison benchmark is an alternative to the more commonly used
            per pupil energy comparison benchmark.
          </p>
          <p>
            Generally, per pupil benchmarks are appropriate for electricity
            (should be proportional to the appliances e.g. ICT in use),
            but per floor area benchmarks are more appropriate for gas (size of
            building which needs heating). Overall, <u>energy</u> use comparison
            on a per pupil basis is probably more appropriate than on a per
            floor area basis, but this analysis can be useful in some circumstances.
          </p>
        </p>
      HTML
    end
  end
end
