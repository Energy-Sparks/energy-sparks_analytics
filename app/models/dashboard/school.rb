# school: defines a school
#         currently derives from Building
#           - TODO(PH,JJ,3Jun18) - at some point decide whether
#           - this is the correct model
#
require_relative '../../../lib/dashboard.rb'

module Dashboard
  class School

    attr_reader :name, :address, :floor_area, :number_of_pupils, :school_type, :area_name, :postcode
    attr_accessor :urn

    def initialize(
      name:,
      address: nil,
      floor_area: nil,
      number_of_pupils: nil,
      school_type: nil,
      area_name: 'Bath',
      urn: nil,
      postcode: nil
    )
      @school_type = school_type
      @name = name
      @address = address
      @floor_area = floor_area
      @number_of_pupils = number_of_pupils
      @school_type = school_type
      @area_name = area_name
      @urn = urn
      @postcode = postcode
    end
  end
end