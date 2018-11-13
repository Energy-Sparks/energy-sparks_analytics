require_relative '../charting_and_reports/multimedia.rb'
# simple placeholder class for holding detail of description results
# type:   :text (a string), :html (snippet), :chart (chart as an example of alert issue)

class AlertDescriptionDetail < MultiMediaDetail
  def initialize(type, content)
    super(type, content)
  end
end
