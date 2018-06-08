# Bath:Hacked Soctrata Electricity and Gas download
#
# electricity data is an array of:
#             "_00_30" => "29.3"
#       ......
#             "_24_00" => "29.3",
#             "date" => "2009-08-10T00:00:00.000",
#             "id" => "a299b2e68dcd7c4c16612d81569f289f",
#             "location" => "Guildhall Electricity Supply 1 (HH)",
#             "mpan" => "2200030370866", || mprn for gas data
#             "msid" => "K05D01635",
#             "postcode" => "BA1 5AW",
#             "totalunits" => "1841.6",
#             "units" => "kWh"
#
# caches results as YAML in local directory ENV["CACHED_METER_READINGS_DIRECTORY"]
# you need to delete files in this directory of you want updated data
# download currently limited to 2000 rows (~6years) to limit impact on Socrata
#
require 'net/http'
require 'json'
require 'date'
require 'soda'
require 'yaml'
require 'benchmark'
require 'pry-byebug'
require_relative '../../app/services/super_aggregate_data_service'
require_relative '../../app/models/school_with_aggregated_data'

def meter_number_column(type)
  type == 'electricity' ? 'mpan' : 'mprn'
end

class LoadSchools
  def initialize
    ENV['SOCRATA_STORE'] = 'data.bathhacked.org'
    ENV['SOCRATA_TOKEN'] = 'gQ5Dw0rIF7I8ij40m8W6ulHj4'
    ENV['SOCRATA_LIMIT'] = '2000'
    @client = SODA::Client.new(domain: ENV['SOCRATA_STORE'], app_token: ENV['SOCRATA_TOKEN'])

    @halfhours = %w(
      _00_30 _01_00 _01_30 _02_00 _02_30 _03_00 _03_30 _04_00
      _04_30 _05_00 _05_30 _06_00 _06_30 _07_00 _07_30 _08_00
      _08_30 _09_00 _09_30 _10_00 _10_30 _11_00 _11_30 _12_00
      _12_30 _13_00 _13_30 _14_00 _14_30 _15_00 _15_30 _16_00
      _16_30 _17_00 _17_30 _18_00 _18_30 _19_00 _19_30 _20_00
      _20_30 _21_00 _21_30 _22_00 _22_30 _23_00 _23_30 _24_00
    )

    ENV['CACHED_METER_READINGS_DIRECTORY'] ||= './MeterReadings/'

    load_schools(ENV['CACHED_METER_READINGS_DIRECTORY'] + 'schoolsandmeters.yml')
  end

  def load_school(school_name, min_date, use_cached_data)
    puts "Loading school #{school_name}"
    school_data = @schools[school_name]

    school = School.new(school_name, school_data[:postcode], school_data[:floor_area], school_data[:pupils], school_data[:school_type])

    swad = SchoolWithAggregatedData.new(school)

    meter_readings = load_school_meter_data(school_name, min_date, use_cached_data)
    create_meters_and_amr_data(swad, meter_readings)

    swad
  end

private

  def create_meters_and_amr_data(school, meter_readings)
    school_data = @schools[school.name]

    school_data[:meters].each do |meter_data|
      meter_type = meter_data[:meter_type]
      identifier_type = meter_type == :electricity ? :mpan : :mprn
      identifier = meter_data[identifier_type]
      puts "hash keys #{meter_data.keys}"
      if meter_data.key?(:deprecated) && meter_data[:deprecated] == true
        puts "Not creating deprecated meter #{identifier}"
      else
        puts "Creating meter #{identifier}"
        meter = create_meter(school, meter_data, meter_readings)
        if meter_data[:meter_type] == :electricity
          school.add_electricity_meter(meter)
        else
          school.add_heat_meter(meter)
        end
      end
    end
  end

  def create_meter(school, meter_data, meter_readings)
    # take meta data for meter from schoolsandmeters.yml file
    # (association of a school with a list of meters)
    ap(meter_data)
    meter_type = meter_data[:meter_type]
    identifier_type = meter_type == :electricity ? :mpan : :mprn
    identifier = meter_data[identifier_type]
    name = meter_data[:name]
    # and combine it with amr data loaded from individual meter data
    # associated with school [identifier] = amr_data
    amr_data = meter_readings[identifier]
    # and combine it to make a meter
    meter = Meter.new(school, amr_data, meter_type, identifier, name, meter_data[:floor_area], meter_data[:pupils])
    meter
  end

  def load_school_meter_data(name, min_date, use_cached_data)
    school_data = @schools[name]
    timing = nil

    meter_readings = {}

    directory_name = ENV['CACHED_METER_READINGS_DIRECTORY']
    Dir.mkdir(directory_name) unless File.exist?(directory_name)

    cached_filename = directory_name + name + '.yml'
    if use_cached_data && File.exist?(cached_filename)
      puts "Loading meter readings from Local Cache for #{name} from #{cached_filename}"
      timing = Benchmark.measure {
        meter_readings = download_from_cache_file(cached_filename)
      }
    else
      puts "Loading meter readings from Bath Hacked Datastore for #{name}"
      timing = Benchmark.measure {
        meter_readings = download_from_bath_hacked(school_data, min_date)
      }
      File.write(cached_filename, meter_readings.to_yaml) if use_cached_data
    end
    summarise_meter_readings(meter_readings)
    puts "Load time #{timing}"
    meter_readings # [identifier] = AMRData{date} => [48 x float]
  end

  def download_from_cache_file(cached_filename)
    YAML::load_file(cached_filename)
  end

  def load_schools(filename)
    puts "Loading school and meter definitions from #{filename}"
    @schools = YAML::load_file(filename)

    @schools.sort.each do |name, school|
      ng = school[:meters].select { |v| v[:meter_type] == :gas }
      ne = school[:meters].select { |v| v[:meter_type] == :electricity }
      printf "\t\t%-40.40s %10.10s gas x %d electricity x %d\n", name, school[:postcode], ng.length, ne.length
    end
  end

  def summarise_meter_readings(meter_readings)
    meter_readings.each do |identifier, data|
      puts "#{identifier} #{data.length} dates from #{data.keys.first} to #{data.keys.last}"
    end
  end

  def download_from_bath_hacked(school, min_date)
    meter_readings = {}
    school[:meters].each do |meter|
      meter_type = meter[:meter_type]
      identifier = meter_type == :electricity ? meter[:mpan] : meter[:mprn]
      meter_readings[identifier] = download_meter_readings(identifier, meter_type, min_date)
    end
    meter_readings
  end

  def query(meter_no, type, since_date = nil)
    column = type == :electricity ? 'mpan' : 'mprn'
    where = '(' + "#{column}='#{meter_no}'" + ')'
    where << " AND date >='#{since_date.iso8601}'" if since_date
    {
        '$where' => where,
        '$order' => 'date ASC',
        '$limit' => ENV['SOCRATA_LIMIT']
    }
  end

  def download_meter_readings(identifier, meter_type, min_date)
    amr_data = AMRData.new(meter_type)
    query = query(identifier, meter_type, min_date)
    table = meter_type == :electricity ? 'fqa5-b8ri' : 'rd4k-3gss'
    @client.get(table, query).each do |days_data|
      date = Date.parse(days_data['date'])
      readings = []
      @halfhours.each do |date_col_identifier|
        readings.push(days_data[date_col_identifier].to_f)
      end
      amr_data.add(date, readings)
    end
    amr_data
  end
end

=begin
class SchoolsLoader
  attr_reader :schools
  def initialize
    @schools = LoadSchools.new
  end

  def load_school(name)
      meter_data = @@schools.load_school(name, Date.new(2010, 9, 1), true)

      @@schools[name][:meters].each do |meter_data|
        meter_data.each do |meter_information|
          meter_type = meter_information[:meter_type]
          name = meter_information[:name]
          identifier_type = meter_type == :electricity ? :mpam : :mprn
          identifier = meter_information[:identifier_type]
          amr_data = meter_data
        meter = Meter.new(initialize(building, amr_data, type, identifier = nil, name = nil))
        end
  end
end
=end

=begin
# class which is only to be used once to create a yml database of schools and meters
# for testing purposes
class BackHackedDownloadSchoolToMeterRelationship

  def initialize
    ENV['SOCRATA_STORE'] = 'data.bathhacked.org'
    ENV['SOCRATA_TOKEN'] = 'gQ5Dw0rIF7I8ij40m8W6ulHj4' # this needs hiding, from Energy Sparks github
    ENV['SOCRATA_LIMIT'] = '2000'
  end

  def query(meter_no, type, since_date = nil)
    column = meter_number_column(type)
    where = '(' + "#{column}='#{meter_no}'" + ')'
    where << " AND date >='#{since_date.iso8601}'" if since_date
    {
        "$select"=> "location, #{column}, postcode, sum(totalunits), count(_00_30)",
        # "$where" => where,
        "$group" => "location, #{column}, postcode"
        # "$order" => "date ASC"
    }
  end

  def download_data
    query = query('2200030370866', 'electricity')

    client = SODA::Client.new(domain: ENV["SOCRATA_STORE"], app_token: ENV["SOCRATA_TOKEN"])

    @school = {}
    client.get('fqa5-b8ri', query).each do |i|
      if !@school.key?(i['postcode'])
        @school[i['postcode']] = { :name => i['location'], :postcode => i['postcode'], :meters => []}
      end
      @school[i['postcode']][:meters].push({ :mpan => i['mpan'], :meter_type => :electricity, :name => i['location'] })
    end

    query = query('2200030370866', 'gas')
    puts "2nd query", query
    client.get("rd4k-3gss", query).each do |i|
      if !@school.key?(i['postcode'])
        @school[i['postcode']] = { :name => i['location'], :postcode => i['postcode'], :meters => []}
      end
      @school[i['postcode']][:meters].push({ :mprn => i['mprn'], :meter_type => :gas, :name => i['location'] })
    end

    @postcodes = @school.keys
    @postcodes.each do |postcode|
      s = @school[postcode]
      @school[s[:name]] = @school.delete(postcode)
    end

    # ap(@school)

    # File.write('./schoolsandmeters1.yml', @school.to_yaml)

    dd = YAML::load_file(ENV['CACHED_METER_READINGS_DIRECTORY'] + 'schoolsandmeters.yml')
  end
end
=end
