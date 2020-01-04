class RunEquivalences < RunCharts

  def run_equivalences(control)
    periods = control[:periods]
    fuel_types = @school.fuel_types(false)
    conversion = EnergyConversions.new(@school)
    list_of_conversions = EnergyConversions.front_end_conversion_list
    fuel_types.each do |fuel_type|
      periods.each do |period|
        name = equivalence_description(fuel_type, period)
        puts "Doing: #{name}"
        equivalence = calculate_equivalence(conversion, list_of_conversions.keys[0], period, fuel_type)
        comparison = CompareContentResults.new(control, @school.name)
        comparison.save_and_compare_content(name, [{ type: :eq, content: equivalence }])
      end
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

  def equivalence_description(fuel_type, period)
    "#{fuel_type} #{period.keys[0]} #{period.values[0]}"
  end
end
