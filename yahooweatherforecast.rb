# Yahoo weather forecast download
#
require 'net/http'
require 'json'
require 'date'
require 'awesome_print'

class YahooWeatherForecast
  attr_reader :forecast # returns a hash(date) => [low, avg, high] forecast in C
  def initialize(location)
    @forecast = {}
    download(location)
  end

  def download(location)
    location = location.downcase
    location = location.gsub(' ', '%20')
    location = location.gsub(',', '%2C')

    url = 'https://query.yahooapis.com/v1/public/yql?q=select%20*%20from%20weather.forecast%20where%20woeid%20in%20(select%20woeid%20from%20geo.places(1)%20where%20text%3D%22<location>%22)&format=json&env=store%3A%2F%2Fdatatables.org%2Falltableswithkeys'

    url = url.gsub('<location>', location)
    uri = URI(url)
    response = Net::HTTP.get(uri)
    data = JSON.parse(response)

    # raw data display: ap(data, color: {float: :red})
    #  forecast data: ap(data['query']['results']['channel']['item']['forecast'], color: {float: :red})

    forecast_days = data['query']['results']['channel']['item']['forecast']

    forecast_days.each do |days_forecast|
      date = Date.parse(days_forecast['date'])
      high = ((days_forecast['high'].to_f - 32.0) * 5.0 / 9.0).round(1)
      low = ((days_forecast['low'].to_f - 32.0) * 5.0 / 9.0).round(1)
      @forecast[date] = [low, ((low + high) / 2.0).round(1), high]
    end
  end
end

# yahoo_forecast = YahooWeatherForecast.new('bath, uk')
