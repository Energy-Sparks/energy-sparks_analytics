# frozen_string_literal: true

require 'spec_helper'
require 'active_support/core_ext'

describe Benchmarking::BenchmarkContentElectricityPerPupil, type: :service do
  let(:benchmark) do
    Benchmarking::BenchmarkContentElectricityPerPupil.new(
      benchmark_database_hash,
      benchmark_database_hash.keys.first,
      :annual_electricity_costs_per_pupil,
      Benchmarking::BenchmarkManager::CHART_TABLE_CONFIG[:annual_electricity_costs_per_pupil]
    )
  end

  describe '#content_title' do
    it 'returns the content title' do
      html = benchmark.send(:content_title)
      expect(html).to match_html(<<~HTML)
        <h1>
          Annual electricity use per pupil with savings potential
        </h1>
      HTML
      title_html = '<h1>' + I18n.t("analytics.benchmarking.chart_table_config.annual_electricity_costs_per_pupil") + '</h1>'
      expect(html).to match_html(title_html)
    end
  end
end
