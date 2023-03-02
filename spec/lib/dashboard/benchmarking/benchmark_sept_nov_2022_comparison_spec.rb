# frozen_string_literal: true

require 'spec_helper'
require 'active_support/core_ext'

describe Benchmarking::BenchmarkSeptNov2022Comparison, type: :service do
  let(:benchmark) do
    Benchmarking::BenchmarkSeptNov2022Comparison.new(
      benchmark_database_hash,
      benchmark_database_hash.keys.first,
      :sept_nov_2021_2022_energy_comparison,
      Benchmarking::BenchmarkManager::CHART_TABLE_CONFIG[:sept_nov_2021_2022_energy_comparison]
    )
  end

  describe '#content_title' do
    it 'returns the content title' do
      html = benchmark.send(:content_title)
      expect(html).to match_html(<<~HTML)
        <h1>
          September to November 2021 versus 2022 energy use
        </h1>
      HTML
      title_html = '<h1>' + I18n.t("analytics.benchmarking.chart_table_config.sept_nov_2021_2022_energy_comparison") + '</h1>'
      expect(html).to match_html(title_html)
    end
  end
end
