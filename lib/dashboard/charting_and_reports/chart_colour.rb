# provides guidance on chart colour
require 'chroma'
require './lib/dashboard/charting_and_reports/interpret_chart' # PH don't know why this is necessary?
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
      puts colour.paint.to_rgb
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
    when /cusum/ # heating day
      '#ff6600'.paint # orange
    when /degree/, /temperature/ # degree days, temperature
      'black'.paint
    else
      'black'.paint
    end
  end
end
