class RunEquivalences < RunCharts

  def run_equivalences(control)
    periods = control[:periods]
    fuel_types = @school.fuel_types(false, false)
    conversion = EnergyConversions.new(@school)
    list_of_conversions = EnergyConversions.front_end_conversion_list
    fuel_types.each do |fuel_type|
      equivalences = {}
      periods.each do |period|
        list_of_conversions.each_key do |equivalence_type|
          name = equivalence_description(fuel_type, period, equivalence_type)
          equivalence = calculate_equivalence(conversion, equivalence_type, period, fuel_type)
          equivalences[name.to_sym] = equivalence
        end
      end
      comparison = CompareContentResults.new(control, @school.name)
      comparison.save_and_compare_content(fuel_type.to_s, [{ type: :eq, content: equivalences }])
    end
  end

  private

  def calculate_equivalence(conversion, type, period, fuel_type)
    equivalence = nil
    begin
      equivalence = conversion.front_end_convert(type, period, fuel_type)
    rescue EnergySparksNotEnoughDataException => e
      equivalence = 'Not enough data'
    end
    equivalence
  end

  def equivalence_description(fuel_type, period, equivalence_type)
    "#{fuel_type}_#{period.keys[0]}_#{period.values[0]}_#{equivalence_type}"
  end
end
