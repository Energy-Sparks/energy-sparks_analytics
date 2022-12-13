#require_relative './dashboard'
module EnergySparksAnalyticsDataHelpers

  #loads a YAML file containing an unvalidated meter collection
  #then turns it into a real MeterCollection object, having
  #validated and aggregated the data
  def load_unvalidated_meter_collection(dir: 'TEST_DIR/MeterCollections', school: 'acme-academy')
    file_name = "#{dir}/unvalidated-data-#{school}.yaml"
    data = load_meter_collection(dir: dir, file_name: file_name)
    meter_collection = create_meter_collection( data )
    validate_and_aggregate( meter_collection )
  end

  #load YAML file
  def load_meter_collection(dir: 'test_output/MeterCollections', file_name:)
    #$stderr.puts "Loading #{file_name}"
    YAML::load_file(file_name)
  end

  #Create a MeterCollection object from a loaded YAML file
  def create_meter_collection(data)
    MeterCollectionFactory.new(
      temperatures:           data[:schedule_data][:temperatures],
      solar_pv:               data[:schedule_data][:solar_pv],
      solar_irradiation:      data[:schedule_data][:solar_irradiation],
      grid_carbon_intensity:  data[:schedule_data][:grid_carbon_intensity],
      holidays:               data[:schedule_data][:holidays]
    ).build(
      school_data:            data[:school_data],
      amr_data:               data[:amr_data],
      meter_attributes_overrides: {},
      pseudo_meter_attributes: data[:pseudo_meter_attributes]
    )
  end

  #Validate and aggregate a MeterCollection
  def validate_and_aggregate(meter_collection)
    AggregateDataService.new(meter_collection).validate_meter_data
    AggregateDataService.new(meter_collection).aggregate_heat_and_electricity_meters
    meter_collection
  end
end

RSpec.configure do |config|
  config.include EnergySparksAnalyticsDataHelpers
end
