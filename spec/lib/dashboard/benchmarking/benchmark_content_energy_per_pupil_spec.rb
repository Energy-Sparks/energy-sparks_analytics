# frozen_string_literal: true

require 'spec_helper'
require 'active_support/core_ext'

describe Benchmarking::BenchmarkContentEnergyPerPupil, type: :service do
  let(:benchmark) do
    Benchmarking::BenchmarkContentEnergyPerPupil.new(
      benchmark_database_hash,
      benchmark_database_hash.keys.first,
      :annual_energy_costs_per_pupil,
      Benchmarking::BenchmarkManager::CHART_TABLE_CONFIG[:annual_energy_costs_per_pupil]
    )
  end

  describe '#content_title' do
    it 'returns the content title' do
      html = benchmark.send(:content_title)
      expect(html).to match_html(<<~HTML)
        <h1>
          Annual energy use per pupil
        </h1>
      HTML
    end
  end

  describe 'introduction_text' do
    it 'formats introduction and any caveat text as html' do
      html = benchmark.send(:introduction_text)
      expect(html).to match_html(<<~HTML)
        <p>
          This benchmark compares the energy consumed per pupil in the last year in kWh.
          Be careful when comparing kWh values between different fuel types,
          <a href="https://en.wikipedia.org/wiki/Primary_energy" target="_blank">
            technically they aren't directly comparable as they are different types of energy.
          </a>
        </p>
        <p>
          Generally, per pupil benchmarks are appropriate for electricity
          (should be proportional to the appliances e.g. ICT in use),
          but per floor area benchmarks are more appropriate for gas (size of
          building which needs heating). Overall, <u>energy</u> use comparison
          on a per pupil basis is probably more appropriate than on a per
          floor area basis, but this analysis can be useful in some circumstances.
        </p>
      HTML
    end
  end
end
