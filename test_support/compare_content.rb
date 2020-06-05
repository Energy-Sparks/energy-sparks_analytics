class CompareContentResults
  attr_reader :control, :school_or_type
  def initialize(control, school_or_type)
    @control = control # [ :summary, :quick_comparison, :report_differing_charts, :report_differences ]
    @school_or_type = school_or_type
    @identical_result_count = 0
    @differing_results = {} # [chart_name] => differences
    @missing = []
  end

  def save_and_compare_content(page, content)
    comparison_content = load_comparison_content(page)
    differences = compare_content(comparison_content, content)
    save_new_content(page, differences)
  end

  def compare_chart_list(chart_list)
    return if control.nil?
    chart_list.each do |name, content|
      save_and_compare_chart_data(name, content)
    end
    puts "Comparison: #{@identical_result_count} matching charts, advice; #{@differing_results.length} differ #{@missing.length} missing" if control_contains?(:summary)
  end

  private

  def comparison_directory
    File.join(control_hash_value(:comparison_directory))
  end

  def output_directory
    File.join(control_hash_value(:output_directory))
  end

  def control_hash_value(type)
    @control[:compare_results].map{ |val| val.is_a?(Hash) ? val.dig(type) : nil }.compact[0]
  end

  private def save_new_content(page, content)
    split_content = split_content(content)
    split_content.each do |key, contents|
      filename = File.join(output_directory, "#{school_or_type} #{page} #{key}.yaml".strip)
      save_yaml_file(filename, contents)
    end
  end

  private def load_comparison_content(page)
    filenames = Dir.glob("#{school_or_type} #{page} *.yaml".strip, base: comparison_directory)
    content = Array.new(filenames.length)
    filenames.each do |filename|
      index_string, key = filename.gsub("#{school_or_type} #{page} ".strip,'').gsub('.yaml', '').split(' ')
      full_filename = File.join(comparison_directory, filename)
      content[index_string.to_i] = { type: key.to_sym, content: load_yaml_file(full_filename) }
    end
    content
  end

  def split_content(content)
    split_content = {}
    content.each_with_index do |content_component, n|
      split_content["#{n} #{content_component[:type]}"] = content_component[:content]
    end
    split_content
  end

  def save_yaml_file(yaml_filename, data)
    File.open(yaml_filename, 'w') { |f| f.write(YAML.dump(data)) }
  end

  def load_yaml_file(yaml_filename)
    YAML::load_file(yaml_filename)
  end

  def compare_content(comparison_content, new_content)
    differences = []
    if comparison_content.length == new_content.length
      comparison_content.each_with_index do |comparison_component, index|
        differences.push(compare_content_component(comparison_component, new_content[index], index))
      end
    else
      differences = new_content
      puts "Number of content components differ: #{comparison_content.length} versus #{new_content.length}"
    end
    differences.compact
  end

  def compare_content_component(comparison_component_orig, new_component_orig, index)
    comparison_component = strip_content_of_volatile_data(comparison_component_orig)
    new_component        = strip_content_of_volatile_data(new_component_orig)
    if comparison_component != new_component
      puts "Differs: #{index}"
      ap @control
      if @control[:compare_results].include?(:report_differences)
        h_diff = Hashdiff.diff(comparison_component, new_component, use_lcs: false, :numeric_tolerance => 0.000001) 
        puts h_diff
        puts 'Versus:'
        puts new_component
      end
      return new_component_orig
    end
    nil
  end

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

  def strip_content_of_volatile_data(content)
    # puts "Removing volatile content"
    content = content.deep_dup
    if content[:content].is_a?(Hash)
      content[:content] = content[:content].except(:calculation_time) 
      unless content[:content][:advice_header].nil?
        content[:content][:advice_header] = remove_volatile_html(content[:content][:advice_header])
      end
    elsif content[:content].is_a?(String)
      content[:content] = remove_volatile_html(content[:content])
    end
    content
  end

  def remove_volatile_html(html)
    [
      ['<p>This saving is equivalent', '</button></p>'],
      ['sourcing its electricity from in the last 5 minutes:', 'The first column'],
      ['National Electricity Grid is currently', ' kg CO2/kWh.'],
      ['<th scope="col"> Percentage of Carbon </th>', '<td> coal </td>'] # not ideal as doesn;t quite match end of table
    ].each do |start_match, end_match|
      html = strip_volatile_content(html, start_match, end_match)
    end
    html
  end

  def strip_volatile_content(html, start_match, end_match)
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
      puts "Chart results for #{chart_name} differ" if control_contains?(:quick_comparison)
      if control_contains?(:report_differences) # HashDiff is horribly slow, so only run if necessary
        h_diff = Hashdiff.diff(old_data, new_data, use_lcs: false, :numeric_tolerance => 0.000001) # use_lcs is O(N) otherwise and takes hours!!!!!
        @differing_results[chart_name] = h_diff
        puts "Chart results for #{chart_name} differ"
        puts h_diff if control_contains?(:quick_comparison)
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
