# maintains history of alerts in CSV file format
# - used for historical analytics
# - for testing purposes - comparing with previous runs of the alerts
#

class AlertHistoryDatabase
  attr_accessor :db_filename

  def initialize
    # @db_filename = full_base_filename
    # @database = Hash.new{ |h,k| h[k] = Hash.new(&h.default_proc) }
    @deliminator = ','
  end

  def add_new_data(updated_alerts)
    @database.merge!(updated_alerts)
  end

  def load
    data = nil
    if File.exists?(filename('.yaml'))
      load_yaml
    else
      puts "File #{filename('.yaml')} doesnt exist, so cant load"
      nil
    end
  end

  def add_data(urn, date, alert_variables)
    alert_variables.each do |alert_variable_name, value|
      @database[urn][date][alert_variable_name.to_s] = value
    end
  end

  def save(data)
    backup_files
    save_csv(data)
    save_yaml(data)
  end

  private

  def load_yaml
    yaml_filename = filename('.yaml')
    puts "Loading #{yaml_filename}"
    return nil unless File.file?(yaml_filename)
    YAML::load_file(yaml_filename)
  end

  def save_yaml(data)
    puts "Saving #{filename('.yaml')}"
    File.open(filename('.yaml'), 'w') { |f| f.write(YAML.dump(data)) }
  end

=begin
  # copied out for moment as UTF encoding format issue in join on load

  # incoming data lines held as sparse
  #   header: 'urn', 'date', 'alert:variable_name_1', 'alert:variable_name_2', 'alert:variable_name_3' etc.
  #   data: 123456, 1 Apr 2019, 25.0,,33.0
  # process to become
  #   @database[123456][1 Apr 2019]['alert:variable_name_1'] = 25.0
  #   @database[123456][1 Apr 2019]['alert:variable_name_3'] = 33.0
  def process_data(lines)
    return nil if lines.nil?
    head = lines[0].split(@deliminator)
    urn_col_num  = column_number(head, 'urn')
    date_col_num = column_number(head, 'date')
    (1...lines.length).each do |line_number|
      line = lines[line_number].split(@deliminator)
      (0...line.length).each do |column_number|
        @database[line[urn_col_num]][Date.parse(line[date_col_num])][head[column_number]] = process_csv_value(line[column_number]) unless line[column_number].nil?
      end
    end
    @database
  end

  def process_csv_value(val_string)
    obj_type_index = 0
    begin
      case obj_type_index
      when 0
        Date.parse(val_string)
      when 1
        if val_string.include?('.')
          val_string.to_f
        else
          val_string.to_i
        end
      else
        val_string.force_encoding(::Encoding::UTF-8)
      end
    rescue StandardError => _e
      puts "failed #{val_string}"
      obj_type_index += 1
      retry
    end
  end
=end
  # reverse of process_data; @database[urn][date][sparse_key] = [sparce_value] => urn,date,,,,,,,sparse_value,,,,, - with sparse_key in the header
  def save_csv(data)
    File.open(filename('.csv'), 'w') do |file|
      head = header(data)
      file.puts(head.join(@deliminator))
      data.each_key do |urn|
        data[urn].each_key do |date|
          line_array = Array.new(head.length)
          line_array[column_number(head, 'urn')] = urn
          line_array[column_number(head, 'date')] = date
          data[urn][date].each do |key, value|
            line_array[column_number(head, key)] = value
          end
          file.puts(line_array.join(@deliminator))
        end
      end
    end
    data
  end

  def column_number(head, key)
    head.find_index(key)
  end

  def filename(extension)
    File.join('./TestResults/Alerts/', 'alerts_history' + extension)
  end

  def backup_filename(datetime, extension)
    File.join('./TestResults/Alerts/Archive/', 'alerts_history ' + datetime + extension)
  end

  def backup_files
    datetime = Time.now.strftime('%Y%b%d-%H%M')
    FileUtils.cp(filename('.csv'), backup_filename(datetime, '.csv')) if File.exists?(filename('.csv'))
    FileUtils.cp(filename('.yaml'), backup_filename(datetime, '.yaml')) if File.exists?(filename('.yaml'))
  end

  def header(data)
    # O(N^2) so could be speeded up!
    head = ['urn', 'date']
    data.each_key do |urn|
      data[urn].each_key do |date|
        data[urn][date].each_key do |key|
          head.push(key) unless head.include?(key)
        end
      end
    end
    head
  end
end
