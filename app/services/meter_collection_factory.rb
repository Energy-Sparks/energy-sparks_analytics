class MeterCollectionFactory

  def self.build(data)
    new(**data[:schedule_data]).build(**data.slice(:school_data, :amr_data, :pseudo_meter_attributes))
  end

  def initialize(temperatures:, solar_pv:, solar_irradiation: nil, grid_carbon_intensity:, holidays:)
    @temperatures = temperatures
    @solar_pv = solar_pv
    @solar_irradiation = solar_irradiation
    @grid_carbon_intensity = grid_carbon_intensity
    @holidays = holidays
  end

  def build(school_data:, amr_data: {electricity_meters: [], heat_meters: []}, pseudo_meter_attributes: {})

    school = Dashboard::School.new(
      name: school_data[:name],
      address: school_data[:address],
      floor_area: school_data[:floor_area],
      number_of_pupils: school_data[:number_of_pupils],
      school_type: school_data[:school_type],
      area_name: school_data[:area_name],
      urn: school_data[:urn],
      postcode: school_data[:postcode]
    )

    meter_collection = MeterCollection.new(school,
                                           temperatures: @temperatures,
                                           solar_pv: @solar_pv,
                                           solar_irradiation: @solar_irradiation,
                                           grid_carbon_intensity: @grid_carbon_intensity,
                                           holidays: @holidays,
                                           pseudo_meter_attributes: pseudo_meter_attributes
                                          )

    add_meters_and_amr_data(meter_collection, amr_data)

    meter_collection
  end

  private

  def add_meters_and_amr_data(meter_collection, meter_data)
    meter_data[:heat_meters].map do |meter|
      dashboard_meter = process_meters(meter_collection, meter)
      meter_collection.add_heat_meter(dashboard_meter)
    end

    meter_data[:electricity_meters].map do |meter|
      dashboard_meter = process_meters(meter_collection, meter)
      meter_collection.add_electricity_meter(dashboard_meter)
    end

    meter_collection
  end

  def process_meters(meter_collection, meter_data)
    parent_meter = build_meter(meter_collection, meter_data)
    meter_data.fetch(:sub_meters){ [] }.each do |sub_meter_data|
      parent_meter.sub_meters.push build_meter(meter_collection, sub_meter_data)
    end
    parent_meter
  end

  def build_meter(meter_collection, meter_data)
    amr_data = AMRData.new(meter_data[:type])
    meter_data[:readings].each do |reading|
      amr_data.add(reading[:reading_date], OneDayAMRReading.new(meter_data[:identifier], reading[:reading_date], reading[:type], reading[:substitute_date], reading[:upload_datetime], reading[:kwh_data_x48]))
    end
    Dashboard::Meter.new(
      meter_collection:   meter_collection,
      amr_data:           amr_data,
      type:               meter_data[:type],
      identifier:         meter_data[:identifier],
      name:               meter_data[:name],
      external_meter_id:  meter_data[:external_meter_id],
      meter_attributes:   meter_data[:attributes]
    )
  end

end
