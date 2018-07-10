# provides guidance on chart colour
require 'chroma'

class ChartColour < InterpretChart
  def initialize(chart_data)
    # super(chart_data)
  end

  # returns a series colour, given a name
  # either as colour_type :hex or :rgb
  # if multiple series or same name, group_number and num_groups will
  # progressively lightens and spins based on spatial range TODO(PH,19Jun18) - its this the best scheme?
  # group_number starts at zero and goes up to num_groups - 1
  def series_colour(series_name, colour_type = :hex, group_number = 0, num_groups = 1)
    colour = series_colour_private(series_name)
    lighten_by = (40 / num_groups) * group_number
    spin_by = (40 / num_groups) * group_number
    colour = colour.lighten(lighten_by).spin(spin_by)
    case colour_type
    when :rgb
      colour.to_rgb
    when :hex
      colour.to_hex
    end
  end

  def self.test
    col = ChartColour.new(nil)

    (0..4).each do |i|
      colour = col.series_colour('some solar pv some time', :rgb, i, 5)
      logger.debug colour.paint.to_rgb
    end
  end

private

  # https://www.w3schools.com/colors/colors_picker.asp?color=00bfff
  # https://github.com/jfairbank/chroma
  def series_colour_private(series_name)
    case series_name.downcase
    when /electricity/
      'red'.paint
    when /gas/
      '#80d4ff'.paint # light blue
    when /solar/
      '#ffff00'.paint # yellow
    when /storage/
      '#ff00ff'.paint # fuchsia
    when /energy/
      'green'.paint
    when /holiday/
      'red'.paint
    when /weekend/
      '#ffa500'.paint # orange
    when /school.*closed/
      '#cc9900'.paint # brown/orange
    when /school.*open/ # in hours
      '#00ff00'.paint # lime
    when /non.*heat/ # non heating day
      '#00ff00'.paint # lime
    when /heat/ # heating day
      'red'.paint
    when /wasted hot water usage/ # non heating day
      'red'.paint # lime
    when /hot water usage/ # heating day
      'blue'.paint
    when /cusum/ # heating day
      '#ff6600'.paint # orange
    when /degree/, /temperature/ # degree days, temperature
      'black'.paint
    when /hot water/
      '#ff3300'.paint
    when /lighting/
      '#ffff99'.paint
    when /servers/
      '#00b33c'.paint
    when /desktops/
      '#66ff99'.paint
    when /laptops/
      '#ccffdd'.paint
    when /boiler pumps/
      '#000099'.paint
    when /security lighting/
      '#cccc00'.paint
    when /kitchen/
      '#ff3399'.paint
    when /air conditioning/
      '#999966'.paint
    when /baseload/
      '#993399'.paint
    else
      'black'.paint
    end
  end
end
