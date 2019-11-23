class ContentBase
  include Logging
  def initialize(school)
    @school = school
    @relevance = check_relevance
    @not_enough_data_exception = false
    @calculation_worked = true
  end

  def relevance
    @relevance
  end

  def no_single_aggregate_meter
    false
  end

  def check_relevance
    return :relevant if no_single_aggregate_meter
    aggregate_meter.nil? ? :never_relevant : :relevant
  end

  def raw_template_variables
    unformatted_template_variables
  end

  def html_template_variables
    formatted_template_variables(:html)
  end

  def text_template_variables
    formatted_template_variables(:text)
  end

  def self.flatten_front_end_template_variables
    variables = {}
    self.template_variables.each do |_group_name, variable_group|
      variables.merge!(variable_group)
    end
    variables
  end

  def self.priority_template_variables
    flatten_front_end_template_variables.select { |_name_sym, data| data.key?(:priority_code) }
  end

  def self.benchmark_template_variables
    flatten_front_end_template_variables.select { |_name_sym, data| data.key?(:benchmark_code) }
  end

  def self.front_end_template_variables
    front_end_template = {}
    self.template_variables.each do |group_name, variable_group|
      map_types = {
        Float     => :float,
        Date      => :date,
        Time      => :datetime,
        String    => :string,
        Integer   => :integer,
        Symbol    => :symbol
      }
      front_end_template[group_name] = {}
      variable_group.each do |type, data|
        next if [:chart, :table, TrueClass].include?(data[:units])
        unless data[:units].is_a?(Symbol) || data[:units].is_a?(Hash)
          if map_types.key?(data[:units])
            data[:units] = map_types[data[:units]]
          else
            raise EnergySparksUnexpectedStateException.new("Missing maps for #{data[:units]} #{data}")
          end
        end
        if [:£_range, :years_range].include?(data[:units]) # convert range values into low and high versions
          front_end_template[group_name].merge!(front_end_high_low_range_values(convert_range_symbol_to_high(type), data, 'high'))
          front_end_template[group_name].merge!(front_end_high_low_range_values(convert_range_symbol_to_low(type),  data, 'low'))
        end
        front_end_template[group_name][type] = data
      end
    end
    front_end_template
  end

  # the front end needs the range type values split into high and low versions
  def self.front_end_high_low_range_values(high_low_type, data, high_low_description_suffix)
    {
      high_low_type => {
        description: data[:description] + ' ' + high_low_description_suffix,
        units: data[:units] == :£_range ? :£ : :years
      }
    }
  end

  def self.convert_range_symbol_to_high(type)
    (type.to_s + '_high').to_sym
  end

  def self.convert_range_symbol_to_low(type)
    (type.to_s + '_low').to_sym
  end 

  def front_end_template_data
    lookup = flatten_template_variables
    raw_data = raw_template_variables
    list = text_template_variables.reject { |type, _value| [:chart, :table, TrueClass].include?(lookup[type][:units]) }
    list.merge(convert_range_template_data_to_high_low(list, lookup, raw_data))
  end

  def priority_template_data
    lookup = flatten_template_variables
    raw_template_variables.select { |type, _value| lookup[type].key?(:priority_code) }
  end

  def benchmark_template_data_deprecated
    lookup = flatten_template_variables
    raw_template_variables.select { |type, _value| lookup[type].key?(:benchmark_code) }
  end

  def benchmark_template_data
    lookup = flatten_template_variables
    benchmark_vars = raw_template_variables.select { |type, _value| lookup[type].key?(:benchmark_code) }

    benchmark_vars.map do |key, value|
      variable_short_code = self.class.benchmark_template_variables[key][:benchmark_code]
      ["#{self.class.short_code}_#{variable_short_code}".to_sym, value]
    end.to_h
  end

  protected def format_array_of_hashes_into_table(rows, keys, units, medium)
    rows.map do |row|
      keys.each_with_index.map do |key, column_number|
        format_for_table(row[key], units[column_number], medium)
      end
    end
  end

  private def format_for_table(value, unit, medium)
    return value if medium == :raw || unit == String
    FormatEnergyUnit.format(unit, value, medium, false, true) 
  end

  private def percent_change(old_value, new_value)
    old_value.nil? ? nil : ((new_value - old_value) / old_value)
  end

  private def convert_range_template_data_to_high_low(template_data, lookup, raw_data)
    new_data = {}
    template_data.each do |type, data| # front end want ranges as seperate high/low symbol-value pairs
      if [:£_range, :years_range].include?(lookup[type][:units])
        new_type = lookup[type][:units] == :£_range ? :£ : :years
        if raw_data[type].nil?
          new_data[self.class.convert_range_symbol_to_high(type)] = nil
          new_data[self.class.convert_range_symbol_to_low(type)]  = nil
        else
          new_data[self.class.convert_range_symbol_to_high(type)] = format(new_type, raw_data[type].first, :text, false, user_numeric_comprehension_level)
          new_data[self.class.convert_range_symbol_to_low(type)]  = format(new_type, raw_data[type].last,  :text, false, user_numeric_comprehension_level)
        end
      end
    end
    new_data
  end

  def raw_variables_for_saving
    raw = {}
    unformatted_template_variables.each do |type, data|
      raw[type] = data
      if data.is_a?(Range)
        raw[self.class.convert_range_symbol_to_low(type)] = data.first
        raw[self.class.convert_range_symbol_to_high(type)] = data.last
      elsif data.is_a?(Array)
        raw.merge!(flatten_table_for_saving(data))
        raw.delete(type)
      end
    end
    raw.transform_keys{ |k| self.class.name + ':' + k.to_s }
  end

  private def flatten_table_for_saving(table)
    data = {}
    header = table[0]
    (1...table.length).each do |row_index|
      (1...table[row_index].length).each do |column_index|
        key = self.class.name + ':' + table[row_index][0].to_s + ':' + header[column_index]
        value = table[row_index][column_index]
        data[key] = value.is_a?(TimeOfDay) ? value.to_s : value
      end
    end
    data
  end

  public_class_method def self.front_end_template_charts
    self.template_variable_by_type(:chart)
  end

  public_class_method def self.front_end_template_tables
    self.template_variable_by_type(:table)
  end

  def self.template_variable_by_type(var_type)
    charts = {}
    template_variables.each do |_group_name, variable_group|
      charts.merge!(variable_group.select { |_type, value| value[:units] == var_type })
    end
    charts
  end

  def front_end_template_chart_data
    charts = front_end_template_chart_data_by_type(:chart)
    charts.reject { |_name, definition| definition.empty? }
  end

  def front_end_template_table_data
    front_end_template_chart_data_by_type(:table)
  end

  private def front_end_template_chart_data_by_type(var_type)
    lookup = flatten_template_variables
    text_template_variables.select { |type, _value| lookup[type][:units] == var_type }
  end

  # returns :enough, :not_enough, :minimum_might_not_be_accurate
  # depending on whether there is enough data to provide the alert
  def enough_data
    raise EnergySparksAbstractBaseClass.new('Error: incorrect attempt to use abstract base class for enough_data template variable ' + self.class.name)
  end

  def days_amr_data
    aggregate_meter.amr_data.end_date - aggregate_meter.amr_data.start_date + 1
  end

  def valid_content?
    return false if @relevance == :never_relevant
    (!@school.aggregated_heat_meters.nil? && needs_gas_data?) ||
      (!@school.aggregated_electricity_meters.nil? && needs_electricity_data?) ||
      (!@school.storage_heater_meter.nil? && needs_storage_heater_data?)
  end

  def make_available_to_users?
    result = relevance == :relevant && enough_data == :enough && calculation_worked
    logger.info "Alert #{self.class.name} not being made available to users: reason: #{relevance} #{enough_data} #{calculation_worked}" if !result
    result
  end

  private

  def formatted_template_variables(format = :html)
    variable_list(true, format)
  end

  def unformatted_template_variables
    variable_list(false)
  end
  
  protected def calculate_rating_from_range(good_value, bad_value, actual_value)
    [10.0 * [(actual_value - bad_value) / (good_value - bad_value), 0.0].max, 10.0].min.round(1)
  end

  protected def flatten_template_variables
    list = {}
    self.class.template_variables.each do |_group_name, variable_group|
      variable_group.each do |type, data|
        list[type] = data
      end
    end
    list
  end

  def variable_data_types
    list = {}
    flatten_template_variables.each do |type, data|
      list[type] = data[:units]
    end
    list
  end

  private def variable_list(formatted, format = :text)
    list = {}
    flatten_template_variables.each do |type, data|
      begin
        if [TrueClass, FalseClass].include?(data[:units])
          list[type] = send(type) # don't reformat flags so can be bound in if tests
        elsif data[:units] == :table
          list[type] = format_table(type, data, formatted, format)
        else
          if respond_to?(type, true)
            if formatted && send(type).nil?
              list[type] = ''
            else
              list[type] = formatted ? format(data[:units], send(type), format, false, user_numeric_comprehension_level) : send(type)
            end
          else
            logger.info "Warning: alert doesnt implement #{type}"
          end
        end
      rescue StandardError => e
        list[type] = e.message
      end
    end
    list
  end

  # convert a table either into an html table, or a '|' bar seperated text table; can't use commas as contined in 1,234 numbers
  private def format_table(type, data_description, formatted, format)
    header, formatted_data = format_table_data(type, data_description, formatted, format)
    return nil if formatted_data.nil?
    table_formatter = AlertRenderTable.new(header, formatted_data)
    table_formatter.render(format)
  end

  protected def user_numeric_comprehension_level
    :ks2
  end

  protected def format(unit, value, format, in_table, level)
    FormatUnit.format(unit, value, format, true, in_table, level)
  end

  # convert the cells within a table into formatted html or text
  private def format_table_data(type, data_description, formatted, format)
    formatted_table = []
    return [nil, nil] unless respond_to? type
    table_data = send(type)
    return [data_description[:header], nil] if table_data.nil?
    column_formats = data_description[:column_types]
    table_data.each do |row_data|
      formatted_row = []
      row_data.each_with_index do |val, index|
        formatted_val = formatted ? format(column_formats[index], val, format, true, user_numeric_comprehension_level) : val
        formatted_row.push(formatted_val)
      end
      formatted_table.push(formatted_row)
    end
    [data_description[:header], formatted_table]
  end

  def needs_gas_data?
    true
  end

  def needs_electricity_data?
    true
  end

  def needs_storage_heater_data?
    false
  end
end