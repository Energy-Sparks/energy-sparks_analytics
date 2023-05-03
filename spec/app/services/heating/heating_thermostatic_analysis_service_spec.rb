# frozen_string_literal: true

require 'spec_helper'

# rubocop:disable Metrics/BlockLength, Layout/LineLength
describe Heating::HeatingThermostaticAnalysisService do
  let(:service) { Heating::HeatingThermostaticAnalysisService.new(meter_collection: @acme_academy, fuel_type: :gas) }
  let(:service_with_storage_heater) { Heating::HeatingThermostaticAnalysisService.new(meter_collection: @beta_academy, fuel_type: :storage_heater) }

  # using before(:all) here to avoid slow loading of YAML and then
  # running the aggregation code for each test.
  before(:all) do
    @acme_academy = load_unvalidated_meter_collection(school: 'acme-academy')
    @beta_academy = load_unvalidated_meter_collection(school: 'beta-academy')
  end

  context '#enough_data?' do
    it 'determines if there is enough data' do
      expect(service.enough_data?).to eq(true)
    end
  end

  # context '#data_available_from?' do
  #   it 'determines when data is available from' do
  #     expect(service.data_available_from).to eq('')
  #   end
  # end

  context '#create_model' do
    it 'creates a model for results of a heating thermostatic analysis for gas' do
      model = service.create_model
      expect(model.r2).to round_to_two_digits(0.67) # 0.6743665142232793
      expect(model.insulation_hotwater_heat_loss_estimate_kwh).to round_to_two_digits(193_133.95) # 193133.95130872616
      expect(model.insulation_hotwater_heat_loss_estimate_£).to round_to_two_digits(5794.02) # 5794.0185392617805
      expect(model.average_heating_school_day_a).to round_to_two_digits(5812.08) # 5812.076809865945
      expect(model.average_heating_school_day_b).to round_to_two_digits(-326.06) # -326.0646866043404
      expect(model.average_outside_temperature_high).to eq(12.0)
      expect(model.average_outside_temperature_low).to eq(4.0)
      expect(model.predicted_kwh_for_high_average_outside_temperature).to round_to_two_digits(1899.3) # 1899.3005706138597
      expect(model.predicted_kwh_for_low_average_outside_temperature).to round_to_two_digits(4507.82) # 4507.818063448583
    end
  end

  context '#create_model' do
    it 'creates a model for results of a heating thermostatic analysis' do
      model = service_with_storage_heater.create_model
      expect(model.r2).to round_to_two_digits(0.37) # 0.36693199874028826
      expect(model.insulation_hotwater_heat_loss_estimate_kwh).to round_to_two_digits(16240.67) # 16240.66843525814
      expect(model.insulation_hotwater_heat_loss_estimate_£).to round_to_two_digits(2436.1) # 2436.1002652887173
      expect(model.average_heating_school_day_a).to round_to_two_digits(798.72) # 798.7242026785364
      expect(model.average_heating_school_day_b).to round_to_two_digits(-29.57) # -29.57015226134058
      expect(model.average_outside_temperature_high).to eq(12.0)
      expect(model.average_outside_temperature_low).to eq(4.0)
      expect(model.predicted_kwh_for_high_average_outside_temperature).to round_to_two_digits(443.88) # 443.8823755424494
      expect(model.predicted_kwh_for_low_average_outside_temperature).to round_to_two_digits(680.44) # 680.443593633174
    end
  end  
end
# rubocop:enable Metrics/BlockLength, Layout/LineLength
