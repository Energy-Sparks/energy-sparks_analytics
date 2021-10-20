class ExemplarSchool < VirtualSchool
  attr_reader :school
  def initialize(name, floor_area, numer_of_pupils)
    super(name, 123456, floor_area, numer_of_pupils)

    create_school
  end

  def calculate
    calculate_exemplar_building_model
    calculate_exemplar_electricity_amr_data
  end

  private

  def calculate_exemplar_electricity_amr_data
    simulator = SimpleExemplarElectricalSimulator.new(school)
    default_simulator_config = simulator.default_simulator_parameters
    exemplar_config = simulator.exemplar(default_simulator_config)
    simulator.simulate(exemplar_config)
  end

  def calculate_exemplar_building_model
    heating_simulator = BuildingHeatHWSimulator.new(school, Date.new(2017, 9, 1), Date.new(2018, 9, 10))
    heating_simulator.simulate
  end
end
