# frozen_string_literal: true

require 'spec_helper'
require 'active_support/core_ext'

describe Benchmarking::BenchmarkElectricityOnDuringHoliday, type: :service do
  let(:benchmark) do
    Benchmarking::BenchmarkElectricityOnDuringHoliday.new(
      benchmark_database_hash,
      benchmark_database_hash.keys.first,
      :electricity_consumption_during_holiday,
      Benchmarking::BenchmarkManager::CHART_TABLE_CONFIG[:electricity_consumption_during_holiday]
    )
  end

  describe '#page' do
    it 'returns a chart name if charts are present' do
      expect(benchmark.page_name).to eq(:electricity_consumption_during_holiday)
    end
  end

  describe '#content_title' do
    it 'returns the content title' do
      html = benchmark.send(:content_title)
      expect(html).to match_html(<<~HTML)
        <h1>
          Electricity use during current holiday
        </h1>
      HTML
      title_html = '<h1>' + I18n.t("analytics.benchmarking.chart_table_config.electricity_consumption_during_holiday") + '</h1>'
      expect(html).to match_html(title_html)
    end
  end

  describe 'introduction_text' do
    it 'formats introduction and any caveat text as html' do
      html = benchmark.send(:introduction_text)
      expect(html).to match_html(<<~HTML)
        <p>
          This benchmark shows the projected electricity costs for the current holiday. No data for a school is shown once the holiday is over. The projection calculation is based on the consumption patterns during the holiday so far.
        </p>
        <p>
          The data excludes storage heaters and any saving the school might get from solar PV.
        </p>
      HTML
      content_html = I18n.t('analytics.benchmarking.content.electricity_consumption_during_holiday.introduction_text_html')
      content_html += I18n.t('analytics.benchmarking.caveat_text.es_exclude_storage_heaters_and_solar_pv_data_html')
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
      expect(benchmark.send(:chart_name)).to eq(:electricity_consumption_during_holiday)
    end
  end

  describe '#tables?' do
    it 'returns if tables are present' do
      expect(benchmark.send(:tables?)).to eq(true)
    end
  end
end