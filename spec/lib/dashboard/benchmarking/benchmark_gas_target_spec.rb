# frozen_string_literal: true

require 'spec_helper'
require 'active_support/core_ext'

describe Benchmarking::BenchmarkGasTarget, type: :service do
  let(:benchmark) do
    Benchmarking::BenchmarkGasTarget.new(
      benchmark_database_hash,
      benchmark_database_hash.keys.first,
      :gas_targets,
      Benchmarking::BenchmarkManager::CHART_TABLE_CONFIG[:gas_targets]
    )
  end

  describe '#content_title' do
    it 'returns the content title' do
      html = benchmark.send(:content_title)
      expect(html).to match_html(<<~HTML)
        <h1>
          Progress against gas target
        </h1>
      HTML
      title_html = '<h1>' + I18n.t("analytics.benchmarking.chart_table_config.gas_targets") + '</h1>'
      expect(html).to match_html(title_html)
    end
  end
end
