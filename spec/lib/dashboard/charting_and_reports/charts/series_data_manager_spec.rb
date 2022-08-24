require 'spec_helper'

describe Series::ManagerBase do
  describe '#series_translation_key_lookup' do
    it 'returns a hash matching series text keys to translation key values' do
      expect(Series::ManagerBase.series_translation_key_lookup).to eq(
        {
        	"Degree Days"=>"degree_days",
          "Temperature"=>"temperature",
          "School Day Closed"=>"school_day_closed",
          "School Day Open"=>"school_day_open",
          "Holiday"=>"holiday",
          "Weekend"=>"weekend",
          "Storage heater charge (school day)"=>"storage_heater_charge",
          "Hot Water Usage"=>"useful_hot_water_usage",
          "Wasted Hot Water Usage"=>"wasted_hot_water_usage",
          "solar pv (consumed onsite)"=>"solar_pv",
          "Solar Irradiance"=>"solar_irradiance",
          "Carbon Intensity of Electricity Grid (kg/kWh)"=>"gridcarbon",
          "Carbon Intensity of Gas (kg/kWh)"=>"gascarbon",
          "Heating on in cold weather"=>"heating_day",
          "Hot Water (& Kitchen)"=>"non_heating_day",
          "Heating on in warm weather"=>"heating_day_warm_weather",
          "electricity"=>"electricity",
          "gas"=>"gas",
          "storage heaters"=>"storage_heaters",
          "Predicted Heat"=>"predicted_heat",
          "Target degree days"=>"target_degree_days",
          "CUSUM"=>"cusum",
          "BASELOAD"=>"baseload",
          "Peak (kW)"=>"peak_kw",
          "Heating On School Days"=>"school_day_heating",
          "Heating On Holidays"=>"holiday_heating",
          "Heating On Weekends"=>"weekend_heating",
          "Hot water/kitchen only On School Days"=>"school_day_hot_water_kitchen",
          "Hot water/kitchen only On Holidays"=>"holiday_hot_water_kitchen",
          "Hot water/kitchen only On Weekends"=>"weekend_hot_water_kitchen",
          "Boiler Off"=>"boiler_off"
        }
      )
    end

    it 'expects there to be translation text for every series translation key' do
      expect(I18n.t('series_data_manager.series').keys.map(&:to_s).sort).to eq(Series::ManagerBase.series_translation_key_lookup.values.sort)
    end
  end

  describe '#translated_series_item_for' do
    it 'returns a translation key for a series given string' do
      I18n.t('series_data_manager.series').each do |key, value|
        expect(Series::ManagerBase.translated_series_item_for(I18n.t("series_data_manager.series.#{key}"))).to eq(value)
      end 
    end

    it 'returns the series string if no translation is found' do
      expect(Series::ManagerBase.translated_series_item_for('This series item is not translated')).to eq('This series item is not translated')
    end    
  end
end