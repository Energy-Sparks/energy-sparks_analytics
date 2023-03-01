# frozen_string_literal: true

require 'spec_helper'
require 'active_support/core_ext'

describe Benchmarking::BenchmarkContentTotalAnnualEnergy, type: :service do
  let(:benchmark) do
    Benchmarking::BenchmarkContentTotalAnnualEnergy.new(
      benchmark_database_hash,
      benchmark_database_hash.keys.first,
      :annual_energy_costs,
      Benchmarking::BenchmarkManager::CHART_TABLE_CONFIG[:annual_energy_costs]
    )
  end

  describe '#content_title' do
    it 'returns the content title' do
      html = benchmark.send(:content_title)
      expect(html).to match_html(<<~HTML)
        <h1>
          Annual energy costs
        </h1>
      HTML
    end
  end

  describe '#introduction_text' do
    it 'formats introduction and any caveat text as html' do
      html = benchmark.send(:introduction_text)
      expect(html).to match_html(<<~HTML)
        <p>
          This benchmark shows how much each school spent on energy last year.
        </p>
      HTML
    end
  end
end
