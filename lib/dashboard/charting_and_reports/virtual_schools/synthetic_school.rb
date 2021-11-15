class SyntheticSchool < MeterCollection
  def initialize(school)
    super(school.school,
          holidays:                 school.holidays,
          temperatures:             school.temperatures,
          solar_irradiation:        school.solar_irradiation,
          solar_pv:                 school.solar_pv,
          grid_carbon_intensity:    school.grid_carbon_intensity,
          pseudo_meter_attributes:  school.pseudo_meter_attributes_private)

    @original_school = school
  end
end
