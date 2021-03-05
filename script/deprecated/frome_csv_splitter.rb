# splits a large csv file into multiple smaller files
# grouped on the defined header column name
# developed to split Bath full.csv 210MB file into indivdual schools by postcode

class CSVSplitter
  def initialize(source_file, destination_directory, split_column_name, delimiter)
    @source_file = source_file
    @destination_directory = destination_directory
    @split_column_name = split_column_name
    @delimiter = delimiter
  end

  def split
    puts "Downloading data from #{@source_file}"
    @file = File.open(@source_file)
    load_data_and_group
    # save_files
  end

  def load_data_and_group
    data = []
    school_name = ''
    meter_id = ''
    mpan_mprn = ''
    @file.each do |line|
      split_col_data = line.gsub('"', '').split(@delimiter)
      if split_col_data[0] == 'SIT:<name>'
        if !data.empty?
          filename = school_name + ' ' + mpan_mprn + '.csv'
          save_file(@destination_directory + '\\' + filename, data)
          data = []
        end
        school_name = split_col_data[1].strip
        school_name = school_name[0, school_name.index('(') - 1]
      else
        chan_id = 'CHN:<channelID>'
        mpan_mprn = split_col_data[1].strip if split_col_data[0][0, chan_id.length] == chan_id
        meter_id = split_col_data[1].strip if split_col_data[0] == 'MET:<name>'
        if split_col_data[0] == 'PCH:'
          data.push(mpan_mprn + ',' + meter_id + ',' + line)
        end
      end
    end
    filename = school_name + ' ' + mpan_mprn + '.csv'
    save_file(@destination_directory + '\\' + filename, data)
  end

  def save_file(filename, data)
    puts "Saving #{filename} with #{data.length} values"
    header = 'Site Id,Meter Number,key,Reading Date,unknown,00:00,00:30,01:00,01:30,02:00,02:30,03:00,03:30,04:00,04:30,05:00,05:30,06:00,06:30,07:00,07:30,08:00,08:30,09:00,09:30,10:00,10:30,11:00,11:30,12:00,12:30,13:00,13:30,14:00,14:30,15:00,15:30,16:00,16:30,17:00,17:30,18:00,18:30,19:00,19:30,20:00,20:30,21:00,21:30,22:00,22:30,23:00,23:30'
    File.open(filename, 'w') do |f|
      f.write(header)
      f.write("\n")
      data.each do |line|
        f.write(line)
      end
    end
  end
end

destination_directory = 'F:\OneDrive\Documents\Transition Bath\Schools Energy Competition\Ruby\Examples\Aggregator Application\energy-sparks_analytics\MeterReadings\Frome'
source_file = destination_directory + '\Historic.csv'

splitter = CSVSplitter.new(source_file, destination_directory,'siteRef', ',')

splitter.split

