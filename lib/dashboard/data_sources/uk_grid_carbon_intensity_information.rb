# interfaces to https://carbon-intensity.github.io/api-definitions/#generation
require 'net/http'
require 'json'
require 'date'
require 'logger'

class UKGridInformation
  include Logging

  attr_reader :energy_source_to_percent

  GRIDCARBONINTENSITYFACTORSKGPERKWH = {
    # note the source strins are identical to the internet download so don't change!
    # http://gridwatch.co.uk/co2-emissions
    'biomass'     =>  0.020, # PH made up
    'coal'        =>  0.870,
    'imports'     =>  0.250,   # PH manually set to this figure, suspect is Netherlands (0.500) and French Nuclear(0.048)
    'gas'         =>  0.394,  # 0.487 figure doesnt look right to PH, is it beldned open and closed cycle? so used http://www.cs.ox.ac.uk/people/alex.rogers/gridcarbon/gridcarbon.pdf
    'nuclear'     =>  0.016,
    'other'       =>  0.250,  # PH manually set to this figure, suspect is Netherlands (0.500) and French Nuclear(0.048)
    'hydro'       =>  0.020,
    'solar'       =>  0.040,
    'wind'        =>  0.011
  }.freeze

  def current_generation_mix
    url = 'https://api.carbonintensity.org.uk/generation'
    response = Net::HTTP.get(URI(url))
    data = JSON.parse(response)
    @energy_source_to_percent = {}
    data['data']['generationmix'].each do |energy_source|
      @energy_source_to_percent[energy_source['fuel']] = (energy_source['perc'].to_f / 100.0).round(3)
    end
    @energy_source_to_percent
  end
end
