# frozen_string_literal: true

module Heating
  # Base class for heating services that need to create a heating model
  class BaseService
    def initialize(meter_collection, asof_date)
      validate_meter_collection(meter_collection)
      @meter_collection = meter_collection
      @asof_date = asof_date
    end

    # Confirms that we are able to successfully generate a heating model from this school's
    # data.
    def enough_data?
      enough_data_for_model_fit? && heating_model.includes_school_day_heating_models?
    end

    def validate_meter_collection(meter_collection)
      if meter_collection.aggregated_heat_meters.nil?
        raise EnergySparksUnexpectedStateException, 'School does not have gas meters'
      end
      if meter_collection.aggregated_heat_meters.non_heating_only?
        raise EnergySparksUnexpectedStateException, 'School does not use gas for heating'
      end
    end

    def aggregate_meter
      @meter_collection.aggregated_heat_meters
    end

    def enough_data_for_model_fit?
      heating_model.enough_samples_for_good_fit
    # FIXME: NoMethodError caught here as it was in original code,
    # but not sure why that's the case. Keeping for now
    rescue EnergySparksNotEnoughDataException, NoMethodError => e
      false
    end

    def heating_model
      @heating_model ||= create_and_fit_model
    end

    private

    def create_and_fit_model
      HeatingModelFactory.new(aggregate_meter, @asof_date).create_model
    end
  end
end
