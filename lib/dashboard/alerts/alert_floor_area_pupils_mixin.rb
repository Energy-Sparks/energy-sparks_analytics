module AlertFloorAreaMixin
  # for floor areas and pupils numbers varying over time
  private def floor_area(start_date = nil, end_date = nil)
    @school.floor_area(start_date, end_date)
  end

  private def pupils(start_date = nil, end_date = nil)
    @school.number_of_pupils(start_date, end_date)
  end
end
