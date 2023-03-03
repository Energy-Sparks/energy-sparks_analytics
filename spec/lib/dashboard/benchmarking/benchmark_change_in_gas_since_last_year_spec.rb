# frozen_string_literal: true

require 'spec_helper'
require 'active_support/core_ext'

describe Benchmarking::BenchmarkChangeInGasSinceLastYear, type: :service do
  let(:benchmark) do
    Benchmarking::BenchmarkChangeInGasSinceLastYear.new(
      benchmark_database_hash,
      benchmark_database_hash.keys.first,
      :change_in_gas_since_last_year,
      Benchmarking::BenchmarkManager::CHART_TABLE_CONFIG[:change_in_gas_since_last_year]
    )
  end

  describe '#page' do
    it 'returns a chart name if charts are present' do
      expect(benchmark.page_name).to eq(:change_in_gas_since_last_year)
    end
  end

  describe '#content_title' do
    it 'returns the content title' do
      html = benchmark.send(:content_title)
      expect(html).to match_html(<<~HTML)
        <h1>
          Annual change in gas use
        </h1>
      HTML
      title_html = '<h1>' + I18n.t("analytics.benchmarking.chart_table_config.change_in_gas_since_last_year") + '</h1>'
      expect(html).to match_html(title_html)
    end
  end

  describe 'introduction_text' do
    it 'formats introduction and any caveat text as html' do
      html = benchmark.send(:introduction_text)
      expect(html).to match_html(<<~HTML)
        <p>
          This table compares gas use between this year to date
          (defined as ‘last year’ in the table below) and the corresponding period
          from the year before (defined as ‘previous year’).
        </p>
        <p>
          The &apos;adjusted&apos; columns are adjusted for difference in
          temperature between the two years. So for example, if the previous year was colder
          than last year, then the adjusted previous year gas consumption
          in kWh is adjusted to last year&apos;s temperatures and would be smaller than
          the unadjusted previous year value. The adjusted percent change is a better
          indicator of the work a school might have done to reduce its energy consumption as
          it&apos;s not dependent on temperature differences between the two years.
        </p>
      HTML
      content_html = I18n.t('analytics.benchmarking.content.change_in_gas_since_last_year.introduction_text_html')
      content_html += I18n.t('analytics.benchmarking.caveat_text.covid_lockdown')
      expect(html).to match_html(content_html)
    end
  end

  describe '#chart_introduction_text' do
    it 'formats chart introduction text as html' do
      html = benchmark.send(:chart_introduction_text)
      expect(html).to match_html(<<~HTML)
      HTML
    end
  end

  describe '#chart_interpretation_text' do
    it 'formats chart interpretation text as html' do
      html = benchmark.send(:chart_interpretation_text)
      expect(html).to match_html(<<~HTML)
      HTML
    end
  end

  describe '#table_introduction_text' do
    it 'formats table introduction text as html' do
      html = benchmark.send(:table_introduction_text)
      expect(html).to match_html(<<~HTML)
      HTML
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
      expect(benchmark.send(:charts?)).to eq(false)
    end
  end

  describe '#chart_name' do
    it 'returns a chart name if charts are present' do
      expect(benchmark.send(:chart_name)).to eq(:change_in_gas_since_last_year)
    end
  end

  describe '#tables?' do
    it 'returns if tables are present' do
      expect(benchmark.send(:tables?)).to eq(true)
    end
  end
end
