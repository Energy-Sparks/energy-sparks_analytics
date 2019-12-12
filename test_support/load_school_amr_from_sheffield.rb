require_relative '../app/services/aggregate_data_service'
require_relative '../app/models/meter_collection'
# creates meter_collection from csv file for Bath school
class LoadSchoolFromSheffieldCSV < MeterReadingsDownloadCSVBase
  include Logging

  @@sheffield_filenames = {
    'Bankwood Primary School' => {
      electricity: [ 
        'Npower (ELEC) Historical HHD for Bankwood Primary 031018.csv',
        'electricity amr data for Bankwood Primary School.csv'
      ],
      gas: [
        'British Gas (GAS) Historical HHD for Bankwood Primary 031018.csv',
        'gas amr data for Bankwood Primary School 6326701.csv'
      ]
    },
    'Ecclesall Primary School' => {
      electricity:  'electricity amr data for Ecclesall Primary School.csv',
      gas:          'gas amr data for Ecckesall Primary School 2155853706.csv'
    },
    'Ecclesfield Primary School' => {
      electricity:  'electricity amr data for Ecclesfield Primary School.csv',
      gas:          'gas amr data for Ecclesfield Primary School 6554602.csv'
    },
    'Hunters Bar School' => {
      electricity:  'electricity amr data for Hunters Bar School.csv',
      gas: [
                    'gas amr data for Hunters Bar 6512204.csv',
                    'gas amr data for Hunters Bar School 6511101.csv',
      ]
    },
    'Lowfields Primary School' => {
      electricity:  'electricity amr data for Lowfields Primary School.csv'
    },
    'Meersbrook Primary School' => {
      electricity:  'electricity amr data for Meersbrook Primary School.csv',
      gas:          'gas amr data for Meersbrook Primary School 9156850403.csv'
    },
    'Mundella Primary School' => {
      electricity:  'electricity amr data for Mundella Primary School.csv',
      gas: [
        'gas amr data for Mundella Primary School 6319210.csv',
        'gas amr data for Mundella Primary School 6319300.csv',
        'gas amr data for Mundella Primary School 9091095306.csv'
      ]
    },
    'Phillimore School' => {
      electricity: 'electricity amr data for Phillimore School.csv',
      gas: [
        'gas amr data for Phillimore School 6442501.csv',
        'gas amr data for Phillimore School 8930321606.csv'
      ]
    },
    'Shortbrook School' => {
      electricity: 'electricity amr data for Shortbrook School.csv',
      gas:          'gas amr data for Shortbrook School 6544408.csv'
    },
    'Valley Park School' => {
      electricity: 'electricity amr data for Valley Park School.csv'
    },
    'Walkley Tennyson School' => {
      gas:          'gas amr data for Walkley School Tennyson School 6500803.csv'
    },
    'Whiteways Primary' => {
      electricity: 'electricity amr data for Whiteways Primary.csv',
      gas: 'gas amr data for Whiteways Primary 2163409301.csv'
    },
    'Woodthorpe Primary School' => {
      electricity: 'electricity amr data for Woodthorpe Primary School.csv',
      gas: 'gas amr data for Woodthorpe Primary School 9120550903.csv'
    },
    'Wybourn Primary School' => {
      electricity: 'electricity amr data for Wybourn Primary School.csv'
    }
  }

  def initialize(meter_collection, meter_attributes)
    super(meter_collection, meter_attributes)
    @delimiter = ','
  end

  def load_meter_readings
    gas_filenames = meter_filenames(@@sheffield_filenames, @meter_collection.name, :gas)

    unless gas_filenames.nil?
      gas_filenames.each do |gas_filename|
        load_british_gas_readings(directory + gas_filename)
      end
    end

    electricity_filenames = meter_filenames(@@sheffield_filenames, @meter_collection.name, :electricity)
    unless electricity_filenames.nil?
      electricity_filenames.each do |electricity_filename|
        load_npower_readings(directory + electricity_filename)
      end
    end
  end

  private

  def load_british_gas_readings(gas_filename)
    logger.info "Loading data from #{gas_filename}"

    @file = File.open(gas_filename)

    @column_names = substitute_unwanted_characters(@file.readline.chomp).split(@delimiter)

    lines = @file.readlines.map(&:chomp)

    logger.info "Downloaded #{lines.length} meter readings"

    lines.each do |line|
      begin
        meter_id, fuel_type, name, one_days_data = process_line_british_gas(:gas, @column_names, line)
        unless meter_id.nil?
          add_reading_to_meter_collection(meter_id, :gas, nil, one_days_data)
        end
      rescue StandardError => _e
        logger.info "Unable to process line #{line}"
      end
    end
  end

  def load_npower_readings(electricity_filename)
    logger.info "Loading data from #{electricity_filename}"

    @file = File.open(electricity_filename)

    @column_names = substitute_unwanted_characters(@file.readline.chomp).split(@delimiter)

    lines = @file.readlines.map(&:chomp)

    logger.info "Downloaded #{lines.length} meter readings"

    lines.each do |line|
      begin
        meter_id, fuel_type, name, one_days_data = process_line_npower(:electricity, @column_names, line)
        unless meter_id.nil?
          add_reading_to_meter_collection(meter_id, :electricity, nil, one_days_data)
        end
      rescue StandardError => _e
        logger.info "Unable to process line #{line}"
      end
    end
  end

  def process_line_british_gas(_type, _column_names, line)
    line_data = substitute_unwanted_characters(line).split(@delimiter)
    date = nil
    date_str = line_data[column_index(@column_names, 'read_date')]
    if date_str.include?('/')
      date = Date.parse(date_str)
    elsif Integer(date_str)
      # 61 is to avoid Excel leap year bug for 1900: https://en.wikipedia.org/wiki/Leap_year_bug
      date = Date.new(1900, 3, 1) + Integer(date_str) - 61
    else
      logger.error "Unknown date format #{date_str}"
      puts "Unknown date format #{date_str}"
    end
    fuel_type = :gas
    mpan_or_mprn = line_data[column_index(@column_names, 'MPR Value')].to_s
    halfhour_kwh_x48 = line_data[column_index(@column_names, 'hh01')..column_index(@column_names, 'hh48')].map(&:to_f)

    one_days_data = OneDayAMRReading.new(mpan_or_mprn, date, 'ORIG', nil, DateTime.now, halfhour_kwh_x48)
    [mpan_or_mprn, fuel_type, nil, one_days_data]
  end

  def process_line_npower(_type, _column_names, line)
    line_data = substitute_unwanted_characters(line).split(@delimiter)
    date = Date.parse(line_data[column_index(@column_names, 'ConsumptionDate')])
    fuel_type = :electricity
    mpan_or_mprn = line_data[column_index(@column_names, 'MPAN')].to_s
    halfhour_kwh_x48 = line_data[column_index(@column_names, 'kWh_1')..column_index(@column_names, 'kWh_48')].map(&:to_f)

    one_days_data = OneDayAMRReading.new(mpan_or_mprn, date, 'ORIG', nil, DateTime.now, halfhour_kwh_x48)
    [mpan_or_mprn, fuel_type, nil, one_days_data]
  end

  def filename
    raise EnergySparksUnexpectedStateException.new('No single file name for loading Sheffield Schools')
  end

  def subdirectory
    'Sheffield'
  end

  def fuel_type(fuel_string)
    case fuel_string.downcase
    when 'electricity'
      :electricity
    when 'gas'
      :gas
    else
      :unknown
    end
  end
end
