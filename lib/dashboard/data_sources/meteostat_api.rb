class MeteoStatApi
  def self.get(url, headers)
    # there seem to be status 429 failures - if you make too
    # many requests in too short a time
    back_off_sleep_times = [0.1, 0.2, 0.5, 1.0, 5.0]
    connection = Faraday.new(url, headers: headers)
    response = nil
    back_off_sleep_times.each do |time_seconds|
      response = connection.get
      break if response.status == 200
      sleep time_seconds
    end
    raise StandardError, "Timed out after #{back_off_sleep_times.length} attempts" if response.status != 200
    JSON.parse(response.body)
  end
end
