# Holds mixed media results from analytics analysis
# this could for example be a mix of html and charts
#
# media  = [ MultiMediaDetail(type, content).........MultiMediaDetail(type, content)]
# so for example charts and html can be mixed in backend and presented to front end for display

class MultiMediaPage < Array  # holding class for storing the mixed media
end

class MultiMediaDetail
  attr_reader :type
  attr_accessor :content

  def initialize(type, content)
    throw EnergySparksUnexpectedStateException("Unexpected nil media type") if type.nil?
    throw EnergySparksUnexpectedStateException.new("Unexpected media type #{type}") unless [:text, :html, :chart].include?(type)
    @type = type
    @content = content
  end

  # to reduce chart debug output
  def to_s
    if type == :html
      content
    elsif type == :chart
      'chart: ' + content[:title]
    else
      content
    end
  end
end
