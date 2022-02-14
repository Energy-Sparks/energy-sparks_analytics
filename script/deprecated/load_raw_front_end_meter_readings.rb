# uses raw file reading rather than 'csv' as its about 50 times faster!
class LoadRawFrontEndMeterReadings
  include Logging
  attr_reader :urn_to_name_map, :mpan_mprn_to_urn_map
  def initialize(filename = '.\MeterReadings\Front End CSV Downloads Non Validated\all-amr-data-feed-readings.csv')
    @filename = filename
  end

  def load_data
    logger.info
    logger.info '=' * 80
    logger.info "Reading raw unvalidated meter readings from #{@filename}"
    bm = Benchmark.realtime {
      @meter_readings_database, @duplicate_data, @incomplete_data, @urn_to_name_map, @mpan_mprn_to_urn_map = load_raw
      logger.error "loaded #{@meter_readings_database.length} meter readings with #{@duplicate_data.length} duplicates and #{@incomplete_data.length} incomplete"
      logger.warn "from #{@mpan_mprn_to_urn_map.length} meters at #{@urn_to_name_map.length} schools"
    }
    logger.info "load time: #{bm.round(1)} seconds"
    logger.info '=' * 80
  end

  def list_of_mpan_mprns
    @meter_readings_database.keys
  end

  def meter_readings(mpan_mprn)
    @meter_readings_database[mpan_mprn.to_s].sort.to_h
  end

  private

  def load_raw
    line_num=0
    duplicate_data = []
    meter_data = Hash.new { |hash, key| hash[key] = {} }
    duplicate_dates = Hash.new { |hash, key| hash[key] = {} }
    incomplete_data = []
    urn_to_name_map = {}
    mpan_mprn_to_urn_map = {}

    data = File.open(@filename).readlines

    mpan_mprn_index, date_index, readings_index, urn_index, school_name_index = header_indexes(data[0])

    (1...data.length).each do |line_number|
      begin
        split_line = data[line_number].chop.split(',')
        mpan_mprn = split_line[mpan_mprn_index]
        date = parse_date(split_line[date_index])
        duplicate_dates[mpan_mprn][date] = split_line[date_index]
        duplicate_data.push("#{line_number}: #{mpan_mprn} #{date}: #{split_line[date_index]} versus #{duplicate_dates[mpan_mprn][date]}") unless meter_data.dig(mpan_mprn, date).nil?
        meter_readings = split_line[readings_index].map { |v| v.empty? ? 0.0 : v.to_f }
        if meter_readings.length == 48
          meter_data[mpan_mprn][date] = OneDayAMRReading.new(mpan_mprn, date, 'ORIG', nil, DateTime.now, meter_readings)
        else
          incomplete_data.push(data[line_number].chop)
        end
        urn_to_name_map[split_line[urn_index]] = split_line[school_name_index]
        mpan_mprn_to_urn_map[mpan_mprn] = split_line[urn_index]
      rescue => e
        logger.info "Error on line number #{line_number} #{e.message}"
      end
    end
    [meter_data, duplicate_data, incomplete_data, urn_to_name_map, mpan_mprn_to_urn_map]  
  end

  def header_indexes(data)
    # School URN	Name	 Mpan Mprn	Reading Date	00:30	01:00 ...... 00:00
    header = data.chop.split(',')
    mpan_mprn_index = header.index('Mpan Mprn') || header.index(' Mpan Mprn')
    date_index = header.index('Reading Date')
    readings_index = Range.new(header.index('00:30'), header.index('00:00'))
    urn_index = header.index('School URN')
    school_name_index = header.index('Name')
    [mpan_mprn_index, date_index, readings_index, urn_index, school_name_index]
  end

  def parse_date(date_str)
    date_str = date_str.strip
    begin
      if date_str.include?('/')
        if date_str.length == 'DD/MM/YYYY'.length
          Date.strptime(date_str, '%d/%m/%Y')
        elsif date_str.length == 'DD/MM/YY'.length
          Date.strptime(date_str, '%d/%m/%y')
        end
      elsif date_str.match?(/^(\d)+$/)
        Date.new(1900, 3, 1) + Integer(date_str) - 61
      else
        Date.parse(date_str)
      end
    rescue => _e
      logger.info e
    end
  end
end
