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

  describe '#page' do
    it 'returns a chart name if charts are present' do
      expect(benchmark.page_name).to eq(:baseload_per_pupil)
    end
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

  describe 'introduction_text' do
    it 'formats introduction and any caveat text as html' do
      html = benchmark.send(:introduction_text)
      expect(html).to match_html(<<~HTML)
        <p>
          A school's baseload is the electricity consumed by appliances kept running at all times.
        </p>
        <p>
          This is one of the most useful benchmarks for understanding a school's electricity use, as 50% of most schools' electricity is consumed out of hours. Reducing the baseload will have a big impact on overall electricity consumption.
        </p>
        <p>
          All schools should aim to reduce their electricity baseload per pupil to that of the best schools. Schools perform roughly the same function so should be able to achieve similar electricity consumption, particularly out of hours.
        </p>
        <p>
          This breakdown excludes electricity consumed by storage heaters and solar PV.
        </p>
      HTML
      content_html = I18n.t('analytics.benchmarking.content.baseload_per_pupil.introduction_text_html') +
        I18n.t('analytics.benchmarking.caveat_text.es_exclude_storage_heaters_and_solar_pv')
      expect(html).to match_html(content_html)
    end
  end

  describe '#table_interpretation_text' do
    it 'formats table interpretation text as html' do
      html = benchmark.send(:table_interpretation_text)
      expect(html).to match_html(<<~HTML)
      HTML
    end
  end

  describe '#caveat_text' do
    it 'formats caveat text as html' do
      html = benchmark.send(:caveat_text)
      expect(html).to match_html(<<~HTML)
      HTML
    end
  end

  describe '#charts?' do
    it 'returns if charts are present' do
      expect(benchmark.send(:charts?)).to eq(true)
    end
  end

  describe '#chart_name' do
    it 'returns a chart name if charts are present' do
      expect(benchmark.send(:chart_name)).to eq(:baseload_per_pupil)
    end
  end

  describe '#tables?' do
    it 'returns if tables are present' do
      expect(benchmark.send(:tables?)).to eq(true)
    end
  end
end