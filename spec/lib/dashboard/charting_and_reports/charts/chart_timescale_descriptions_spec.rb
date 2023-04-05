require 'spec_helper'

describe ChartTimeScaleDescriptions do
  context '.timescale_name' do
    it 'returns expected values' do
      expect(ChartTimeScaleDescriptions.timescale_name(:year)).to eq 'year'
      expect(ChartTimeScaleDescriptions.timescale_name(:up_to_a_year)).to eq 'year'
      expect(ChartTimeScaleDescriptions.timescale_name(:years)).to eq 'long term'
      expect(ChartTimeScaleDescriptions.timescale_name(:academicyear)).to eq 'academic year'
      expect(ChartTimeScaleDescriptions.timescale_name(:month)).to eq 'month'
      expect(ChartTimeScaleDescriptions.timescale_name(:holiday)).to eq 'holiday'
      expect(ChartTimeScaleDescriptions.timescale_name(:includeholiday)).to eq 'holiday'
      expect(ChartTimeScaleDescriptions.timescale_name(:week)).to eq 'week'
      expect(ChartTimeScaleDescriptions.timescale_name(:schoolweek)).to eq 'school week'
      expect(ChartTimeScaleDescriptions.timescale_name(:day)).to eq 'day'
      expect(ChartTimeScaleDescriptions.timescale_name(:frostday)).to eq 'frosty day'
      expect(ChartTimeScaleDescriptions.timescale_name(:frostday_3)).to eq 'frosty day'
      expect(ChartTimeScaleDescriptions.timescale_name(:diurnal)).to eq 'day with large diurnal range'
      expect(ChartTimeScaleDescriptions.timescale_name(:optimum_start)).to eq 'optimum start example day'
      expect(ChartTimeScaleDescriptions.timescale_name(:daterange)).to eq 'date range'
      expect(ChartTimeScaleDescriptions.timescale_name(:hotwater)).to eq 'summer period with hot water usage'
      expect(ChartTimeScaleDescriptions.timescale_name(:none)).to eq ''
      expect(ChartTimeScaleDescriptions.timescale_name(:period)).to eq 'period'
    end
  end

  context '.interpret_timescale_description' do
    it 'returns expected description' do
      expect(ChartTimeScaleDescriptions.interpret_timescale_description(:up_to_a_year)).to eq 'year'
      expect(ChartTimeScaleDescriptions.interpret_timescale_description(:none)).to eq ''
      expect(ChartTimeScaleDescriptions.interpret_timescale_description(:unknown)).to eq 'period'
      timescale = {schoolweek: -1}
      expect(ChartTimeScaleDescriptions.interpret_timescale_description(timescale)).to eq 'school week'
      timescale = {week: -1..0}
      expect(ChartTimeScaleDescriptions.interpret_timescale_description(timescale)).to eq 'week'
      timescale = [{year: 0}, {year: -1}]
      expect(ChartTimeScaleDescriptions.interpret_timescale_description(timescale)).to eq 'year'
      timescale = {daterange: Date.today..Date.today}
      expect(ChartTimeScaleDescriptions.interpret_timescale_description(timescale)).to eq 'day'
      timescale = {daterange: Date.today-6..Date.today}
      expect(ChartTimeScaleDescriptions.interpret_timescale_description(timescale)).to eq 'week'
      timescale = {daterange: Date.today-30..Date.today}
      expect(ChartTimeScaleDescriptions.interpret_timescale_description(timescale)).to eq 'month'
      timescale = {daterange: Date.today-365..Date.today}
      expect(ChartTimeScaleDescriptions.interpret_timescale_description(timescale)).to eq 'year'
      timescale = {daterange: Date.today-500..Date.today}
      expect(ChartTimeScaleDescriptions.interpret_timescale_description(timescale)).to eq 'long term'
      timescale = {daterange: Date.today-69..Date.today}
      expect(ChartTimeScaleDescriptions.interpret_timescale_description(timescale)).to eq '10 weeks'
    end
  end

end
