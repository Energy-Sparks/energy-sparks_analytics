class CompareChartResults
  attr_reader :control, :school_name
  def initialize(control, school_name)
    @control = control # [ :summary, :quick_comparison, :report_differing_charts, :report_differences ]
    @school_name = school_name
    @identical_result_count = 0
    @differing_results = {} # [chart_name] => differences
    @missing = []
  end

  def compare_results(all_charts)
    return if control.nil?
    all_charts.each do |chart|
      save_and_compare_chart_data(chart[:name], chart)
    end
    puts "Comparison: #{@identical_result_count} matching charts, advice; #{@differing_results.length} differ #{@missing.length} missing" if control_contains?(:summary)
  end

  private

  def save_and_compare_chart_data(chart_name, charts)
    if chart_name.is_a?(Hash)
      puts 'Unable to save and compare composite chart'
      return
    end
    save_chart(TestDirectoryConfiguration::CHARTCOMPARISONNEW, chart_name, charts)
    previous_chart = load_chart(TestDirectoryConfiguration::CHARTCOMPARISONBASE, chart_name)
    if previous_chart.nil?
      @missing.push(chart_name)
      return
    end
    compare_charts(chart_name, previous_chart, charts)
  end

  def strip_chart_of_volatile_data(chart)
    chart = chart.clone
    chart.delete(:calculation_time)
    unless chart[:advice_header].nil?
      chart[:advice_header] = remove_volatile_html(chart[:advice_header], '<p>This saving is equivalent', '</button></p>')
      chart[:advice_header] = remove_volatile_html(chart[:advice_header], 'sourcing its electricity from in the last 5 minutes:', 'The first column')
      chart[:advice_header] = remove_volatile_html(chart[:advice_header], 'National Electricity Grid is currently', ' kg CO2/kWh.')
    end
    chart
  end

  
  def remove_volatile_html(html, start_match, end_match)
    start_index = html.index(start_match)
    end_index = html.index(end_match)

    if !start_index.nil? && !end_index.nil?
      end_index = html.index(end_match) + end_match.length
      html = html[0...start_index] + html[end_index...html.length]
    elsif !start_index.nil? && !end_index.nil? && start_index >= end_index
      puts 'Start and index for remove_volatile_html in wrong order - consider longer match on text'
    end
    html
  end

  def compare_charts(chart_name, old_data, new_data)
    old_data = strip_chart_of_volatile_data(old_data)
    new_data = strip_chart_of_volatile_data(new_data)
    same = old_data == new_data
    if same
      @identical_result_count +=1
    else
      @differing_results[chart_name] = true # set for summary purposes
      if !control_contains?(:quick_comparison) # HashDiff is horribly slow, so only run if necessary
        h_diff = Hashdiff.diff(old_data, new_data, use_lcs: false, :numeric_tolerance => 0.000001) # use_lcs is O(N) otherwise and takes hours!!!!!
        @differing_results[chart_name] = h_diff
        puts "Chart results for #{chart_name} differ"
        puts h_diff
      end
    end
  end

  def load_chart(path, chart_name)
    yaml_filename = yml_filepath(path, chart_name)
    return nil unless File.file?(yaml_filename)
    YAML::load_file(yaml_filename)
  end

  def save_chart(path, chart_name, data)
    yaml_filename = yml_filepath(path, chart_name)
    File.open(yaml_filename, 'w') { |f| f.write(YAML.dump(data)) }
  end

  def control_contains?(key)
    return true if control.include?(key)
    hash_controls.key?(key)
  end

  def hash_controls
    h = control.select { |entry| entry.is_a?(Hash) }.inject(:merge)
    h.nil? ? {} : h
  end

  def yml_filepath(path, chart_name)
    full_path ||= File.join(File.dirname(__FILE__), path)
    Dir.mkdir(full_path) unless File.exist?(full_path)
    extension = control_contains?(:name_extension) ? ('- ' + hash_controls[:name_extension].to_s) : ''
    yaml_filename = full_path + @school_name + '-' + chart_name.to_s + extension + '.yaml'
    yaml_filename.length > 259 ? shorten_filename(yaml_filename) : yaml_filename
  end
end
