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
    attr_reader :name, :id, :address, :floor_area, :number_of_pupils, :school_type, :area_name, :postcode, :country, :funding_status, :activation_date, :created_at, :school_times, :community_use_times, :location, :data_enabled
    attr_accessor :urn

    def initialize(
      name:,
      id: nil,
      address: nil,
      floor_area: nil,
      number_of_pupils: nil,
      school_type: nil,
      area_name: 'Bath',
      urn: nil,
      funding_status: nil,
      postcode: nil,
      country: nil,
      activation_date: nil,
      created_at: nil,
      school_times: [],
      community_use_times: [],
      location: [],
      data_enabled: true
    )
      @school_type = school_type
      @name = name
      @id = id
      @address = address
      @floor_area = floor_area
      @number_of_pupils = number_of_pupils
      @school_type = school_type
      @area_name = area_name
      @urn = urn
      @funding_status = funding_status
      @postcode = postcode
      @country = country
      @activation_date = activation_date
      @created_at = created_at
      @school_times = school_times
      @community_use_times = community_use_times
      @location = location
      @data_enabled = data_enabled
    end

    def latitude
      return nil if @location.nil?
      @location[0].to_f
    end

    def longitude
      return nil if @location.nil?
      @location[1].to_f
    end

    def activation_date
      return nil if @activation_date.nil?
      # the time is passed in as an active_support Time and not a ruby Time
      # from the front end, so can't be used directly, the utc field needs to be accessed
      # instead
      t = @activation_date.respond_to?(:utc) ? @activation_date.utc : @activation_date
      Date.new(t.year, t.month, t.day)
    end

    def creation_date
      return nil if @created_at.nil?
      # the time is passed in as an active_support Time and not a ruby Time
      # from the front end, so can't be used directly, the utc field needs to be accessed
      # instead
      t = @created_at.respond_to?(:utc) ? @created_at.utc : @created_at
      Date.new(t.year, t.month, t.day)
    end

    def to_s
      "#{name} - #{urn} - #{school_type} - #{area_name} - Activated: #{activation_date} - Created: #{created_at}"
    end
  end
end
