class LatitudeLongitude
  def self.distance(from_latitude, from_longitude, to_latitude, to_longitude)
    radius_earth_km = 6371.0
    latitude_diff   = degrees_to_radians(to_latitude - from_latitude)
    longitude_diff  = degrees_to_radians(to_longitude- from_longitude)
    a = Math.sin(latitude_diff / 2.0) * Math.sin(latitude_diff / 2.0) +
        Math.cos(degrees_to_radians(from_latitude)) * Math.cos(degrees_to_radians(to_latitude)) * 
        Math.sin(longitude_diff / 2.0) * Math.sin(longitude_diff / 2.0)
    c = 2.0 * Math.atan2(a**0.5, (1-a)**0.5)
    radius_earth_km * c
  end
  
  def self.degrees_to_radians(degrees)
    degrees * Math::PI / 180.0
  end
end
