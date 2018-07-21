# simple placeholder class for holding detail of description results
# type:   :text (a string), :html (snippet), :chart (chart as an example of alert issue)

class AlertDescriptionDetail
  attr_reader :type, :content

  def initialize(type, content)
    @type = type
    @content = content
  end
end