
require_relative './advice_general.rb'
require_relative '../benchmarking/benchmark_content_general.rb'
class AdviceRefrigeration < AdviceElectricityBase
  def baseload_one_year_chart
    @bdown_1year_chart ||= charts[0]
  end

  def content(user_type: nil)
    charts_and_html = []
    charts_and_html.push( { type: :html, content: "<h2>Refrigeration</h2>" } )
    charts_and_html += debug_content
    charts_and_html.push( { type: :html,  content: Benchmarking::BenchmarkRefrigeration.intro } )
    charts_and_html.push( { type: :chart, content: baseload_one_year_chart } )

    remove_diagnostics_from_html(charts_and_html, user_type)
  end 
end
