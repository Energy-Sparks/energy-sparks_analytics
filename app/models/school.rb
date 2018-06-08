# school: defines a school
#         currently derives from Building
#           - TODO(PH,JJ,3Jun18) - at some point decide whether
#           - this is the correct model
require_relative '../../lib/dashboard.rb'

class School #< Building
  # Energy Sparks activerecord fields:
  # These are objects from the actual school record

  attr_reader :name, :address, :floor_area, :number_of_pupils

  attr_reader :address, :calendar_id, :competition_role, :created_at, :electricity_dataset, :enrolled
  attr_reader :gas_dataset, :id, :level, :name, :postcode, :sash_id, :school_type, :slug, :update_at
  attr_reader :urn, :website

  def initialize(name, address = nil, floor_area = nil, pupils = nil, type = nil)
    @school_type = type
  end

end
