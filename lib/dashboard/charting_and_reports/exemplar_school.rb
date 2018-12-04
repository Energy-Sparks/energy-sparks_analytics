class ExemplarSchool < VirtualSchool
  attr_reader :school
  def initialize(name, floor_area, numer_of_pupils)
    super(name, 123456, floor_area, numer_of_pupils)

    create_school
  end

  def calculate
  end
end
