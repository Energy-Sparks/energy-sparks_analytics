# school: defines a school
#         currently derives from Building
#           - TODO(PH,JJ,3Jun18) - at some point decide whether
#           - this is the correct model
#
require_relative '../../../lib/dashboard.rb'

module Dashboard
  class School

    # Activation date is when the school was activated by an administrator in the Energy Sparks front end - it is a date
    # Created at is when the school was created during the onboarding process - it is a timestamp
    attr_reader :name, :address, :floor_area, :number_of_pupils, :school_type, :area_name, :postcode, :activation_date, :created_at, :school_times, :community_use_times, :location, :data_enabled
    attr_accessor :urn

    def initialize(
      name:,
      address: nil,
      floor_area: nil,
      number_of_pupils: nil,
      school_type: nil,
      area_name: 'Bath',
      urn: nil,
      postcode: nil,
      activation_date: nil,
      created_at: nil,
      school_times: [],
      community_use_times: [],
      location: [],
      data_enabled: true
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
      @activation_date = activation_date
      @created_at = created_at
      @school_times = school_times
      @community_use_times = community_use_times
      @location = location
      @data_enabled = data_enabled
    end

    def to_s
      "#{name} - #{urn} - #{school_type} - #{area_name} - Activated: #{activation_date} - Created: #{created_at}"
    end
  end
end
