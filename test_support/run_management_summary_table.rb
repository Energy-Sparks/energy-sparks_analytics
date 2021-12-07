class RunManagementSummaryTable < RunCharts
  attr_reader :html
  def run_management_table(control)
    results = calculate
    compare_results(control, results)
    @html = results[:html]
  end

  private

  def calculate
    content = ManagementSummaryTable.new(@school)
    puts 'Invalid content' unless content.valid_content?
    content.analyse(nil)
    puts 'Content failed' unless content.make_available_to_users?

    {
      front_end_template_tables:      ManagementSummaryTable.front_end_template_tables,
      front_end_template_table_data:  content.front_end_template_table_data,
      raw_variables_for_saving:       content.raw_variables_for_saving,
      html:                           combined_html(content)
    }
  end

  def combined_html(content)
    content.html + content.multirow_html + content.meter_range_html
  end

  def compare_results(control, results)
    results.each do |type, content|
      comparison = CompareContentResults.new(control, @school.name)
      comparison.save_and_compare_content(type.to_s, [{ type: type, content: content }])
    end
  end
end
