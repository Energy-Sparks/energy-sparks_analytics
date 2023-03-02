# frozen_string_literal: true

require 'spec_helper'
require 'active_support/core_ext'

describe Benchmarking::BenchmarkContentChangeInBaseloadSinceLastYear, type: :service do
  let(:benchmark) do
    Benchmarking::BenchmarkContentChangeInBaseloadSinceLastYear.new(
      benchmark_database_hash,
      benchmark_database_hash.keys.first,
      :recent_change_in_baseload,
      Benchmarking::BenchmarkManager::CHART_TABLE_CONFIG[:recent_change_in_baseload]
    )
  end

  describe '#content_title' do
    it 'returns the content title' do
      html = benchmark.send(:content_title)
      expect(html).to match_html(<<~HTML)
        <h1>
          Recent change in baseload
        </h1>
      HTML
      title_html = '<h1>' + I18n.t("analytics.benchmarking.chart_table_config.recent_change_in_baseload") + '</h1>'
      expect(html).to match_html(title_html)
    end
  end
end
