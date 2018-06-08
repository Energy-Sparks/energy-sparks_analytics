require 'spec_helper'
require_relative '../lib/dashboard'
require_relative '../test_support/school_factory'
require_relative '../test_support/schedule_data_manager'
require 'roo'

describe 'aggregate data service' do

  it 'processes a yaml file from bath hacked and aggregates the data' do
    expected_school = YAML.load_file('test_support/paulton-junior-school-aggregated.yaml')
    pp "loaded file"

    # making some more changes here, and some more
    school_name = 'Paulton Junior School' # ''

    ENV[SchoolFactory::ENV_SCHOOL_DATA_SOURCE] = SchoolFactory::BATH_HACKED_SCHOOL_DATA
    ENV['CACHED_METER_READINGS_DIRECTORY'] = './MeterReadings/'

    $SCHOOL_FACTORY = SchoolFactory.new

    school = $SCHOOL_FACTORY.load_school(school_name)

    expect(school.name).to eq school_name
    expect(school.aggregated_heat_meters.amr_data.first).to eq expected_school.aggregated_heat_meters.amr_data.first
  end
end