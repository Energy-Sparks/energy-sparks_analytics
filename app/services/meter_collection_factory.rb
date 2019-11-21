class MeterCollectionFactory

  def initialize(temperatures:, solar_pv:, solar_irradiation:, grid_carbon_intensity:, holidays:)
    @temperatures = temperatures
    @solar_pv = solar_pv
    @solar_irradiation = solar_irradiation
    @grid_carbon_intensity = grid_carbon_intensity
    @holidays = holidays
  end

  def build(school:, meter_data: {electricity_meters: [], heat_meters: []}, meter_attributes: {})

    meter_collection = MeterCollection.new(school,
                                           temperatures: @temperatures,
                                           solar_pv: @solar_pv,
                                           solar_irradiation: @solar_irradiation,
                                           grid_carbon_intensity: @uk_grid_carbon_intensity,
                                           holidays: @holidays
                                          )

    add_meters_and_amr_data(meter_collection, meter_data, meter_attributes)

    meter_collection
  end

  private

  def add_meters_and_amr_data(meter_collection, meter_data, meter_attributes)
    meter_data[:heat_meters].map do |meter|
      dashboard_meter = process_meters(meter_collection, meter, meter_attributes)
      meter_collection.add_heat_meter(dashboard_meter)
    end

    meter_data[:electricity_meters].map do |meter|
      dashboard_meter = process_meters(meter_collection, meter, meter_attributes)
      meter_collection.add_electricity_meter(dashboard_meter)
    end

    meter_collection
  end

  def process_meters(meter_collection, meter_data, meter_attributes)
    parent_meter = build_meter(meter_collection, meter_data, meter_attributes)
    meter_data.fetch(:sub_meters){ [] }.each do |sub_meter_data|
      parent_meter.sub_meters.push build_meter(meter_collection, sub_meter_data, meter_attributes)
    end
    parent_meter
  end

  def build_meter(meter_collection, meter_data, meter_attributes)
    attributes = meter_attributes.fetch(meter_data[:identifier]){ {} }
    amr_data = AMRData.new(meter_data[:type])
    meter_data[:readings].each do |reading|
      amr_data.add(reading[:reading_date], OneDayAMRReading.new(reading[:meter_id], reading[:reading_date], reading[:type], reading[:substitute_date], reading[:upload_datetime], reading[:kwh_data_x48]))
    end
    Dashboard::Meter.new(
      meter_collection:   meter_collection,
      amr_data:           amr_data,
      type:               meter_data[:type],
      identifier:         meter_data[:identifier],
      name:               meter_data[:name],
      external_meter_id:  meter_data[:external_meter_id],
      meter_attributes:   attributes
    )
  end

end
