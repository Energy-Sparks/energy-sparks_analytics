# location for managing (analytics?) geo location information
class AreaNameGeoLocations
  LOCATIONS = {
    'Bath'      => { latitude: 51.39,   longitude: -2.37 },
    'Sheffield' => { latitude: 53.3811, longitude: -1.4701 },
    'Frome'     => { latitude: 51.2308, longitude: -2.3201 }
  }.freeze

  def self.latitude_longitude_from_area_name(area_name)
    [LOCATIONS[area_name][:latitude], LOCATIONS[area_name][:longitude]]
  end
end