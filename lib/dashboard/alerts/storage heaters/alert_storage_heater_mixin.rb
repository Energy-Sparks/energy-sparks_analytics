module AlertGasToStorageHeaterSubstitutionMixIn
  protected def aggregate_meter
    @school.storage_heater_meter
  end

  def needs_storage_heater_data?
    true
  end

  def aggregate_meter
    @school.storage_heater_meter
  end

  def fuel_price_deprecated
    BenchmarkMetrics::ELECTRICITY_PRICE # deprecated
  end

  # benchmark some storage heater alerts against gas cost e.g. per floor area
  # as gas is cheaper and it should be clear to schools that gas is a better choice
  # from a cost perspective, if the school has gas as well then use that tariff
  def defaulted_gas_tariff_£_per_kwh
    if @school.aggregated_heat_meters.nil?
      BenchmarkMetrics::GAS_PRICE
    else
      @school.aggregated_heat_meters.amr_data.blended_rate(:kwh, :£).round(5)
    end
  end

  def self.fuel_lc
    'storage heater'
  end

  def self.fuel_cap
    'Storage heater'
  end

  def self.template_variables
    specific = self.superclass.template_variables
    substitute_template_variables_fuel_type(specific, 'gas', 'storage heater', 'Gas', 'Storage heater', :electricity)
    specific
  end

  def self.substitute_template_variables_fuel_type(variable_groups, from_lc, to_lc, from_cap, to_cap, fuel_sym)
    variable_groups.transform_keys! { |key| key.gsub(from_lc, to_lc).gsub(from_cap, to_cap) }
    variable_groups.each do |group_description, variables|
      variables.each do |variable, definition|
        definition[:units] = { kwh: fuel_sym } if definition.key?(:units) && definition[:units].is_a?(Hash) && definition[:units].key?(:kwh)
        definition[:units] = { £:   fuel_sym } if definition.key?(:units) && definition[:units].is_a?(Hash) && definition[:units].key?(:£)
        if definition.key?(:description) && !definition[:description].nil?
          definition[:description] = definition[:description].gsub(from_lc, to_lc).gsub(from_cap, to_cap) 
        end
      end
    end
    variable_groups
  end

  # needs electricity_cost_co2_mixin.rb
  def gas_cost_deprecated(kwh)
    kwh * blended_electricity_£_per_kwh
  end

  def gas_co2(kwh)
    kwh * blended_co2_per_kwh
  end

  def tariff
    blended_electricity_£_per_kwh
  end

  def co2_intensity_per_kwh
    blended_co2_per_kwh
  end
end
