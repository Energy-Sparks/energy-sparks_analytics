# frozen_string_literal: true

require 'spec_helper'
require 'active_support/core_ext'

describe Benchmarking::BenchmarkContentBaseloadPerPupil, type: :service do
  let(:benchmark) do
    Benchmarking::BenchmarkContentBaseloadPerPupil.new(
      benchmark_database_hash,
      benchmark_database_hash.keys.first,
      :baseload_per_pupil,
      Benchmarking::BenchmarkManager::CHART_TABLE_CONFIG[:baseload_per_pupil]
    )
  end

  describe '#content_title' do
    it 'returns the content title' do
      html = benchmark.send(:content_title)
      expect(html).to match_html(<<~HTML)
        <h1>
          Baseload per pupil
        </h1>
      HTML
      title_html = '<h1>' + I18n.t("analytics.benchmarking.chart_table_config.baseload_per_pupil") + '</h1>'
      expect(html).to match_html(title_html)
    end
  end
end
