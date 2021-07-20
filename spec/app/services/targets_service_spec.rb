require 'spec_helper'

describe TargetsService do

  context 'with valid data' do

    context "#monthly_progress" do

      let(:meter_collection)        { build(:meter_collection) }
      let(:service)                 { TargetsService.new(meter_collection) }

      let(:raw_data) do
        {
          current_year_kwhs: [1111.11] + Array.new(11) { rand(100000) },
          full_targets_kwh: [2222.22] + Array.new(11) { rand(100000) },
          partial_targets_kwh: [3333] + Array.new(11) { rand(100000) },
          full_cumulative_current_year_kwhs: [4444.44] + Array.new(11) { rand(100000) },
          full_cumulative_targets_kwhs: [5555.55] + Array.new(11) { rand(100000) },
          partial_cumulative_targets_kwhs: [6666] + Array.new(11) { rand(100000) },
          monthly_performance: [77.77] + Array.new(11) { rand(100) },
          cumulative_performance: [88.88] + Array.new(11) { rand(100) },
          current_year_date_ranges: [
            dates('Tue, 01 Sep 2020','Wed, 30 Sep 2020'),
            dates('Thu, 01 Oct 2020','Sat, 31 Oct 2020'),
            dates('Sun, 01 Nov 2020','Mon, 30 Nov 2020'),
            dates('Tue, 01 Dec 2020','Thu, 31 Dec 2020'),
            dates('Fri, 01 Jan 2021','Sun, 31 Jan 2021'),
            dates('Mon, 01 Feb 2021','Sun, 28 Feb 2021'),
            dates('Mon, 01 Mar 2021','Wed, 31 Mar 2021'),
            dates('Thu, 01 Apr 2021','Fri, 30 Apr 2021'),
            dates('Sat, 01 May 2021','Mon, 31 May 2021'),
            dates('Tue, 01 Jun 2021','Wed, 30 Jun 2021'),
            dates('Thu, 01 Jul 2021','Sat, 31 Jul 2021'),
            dates('Sun, 01 Aug 2021','Tue, 31 Aug 2021')
           ]
        }
      end

      def dates(first, last)
        Date.parse(first)..Date.parse(last)
      end

      before do
        allow_any_instance_of(CalculateMonthlyTrackAndTraceData).to receive(:raw_data).and_return(raw_data)
      end

      it 'returns monthly progress' do
        monthly_progress = service.monthly_progress

        expect(monthly_progress.keys).to include('Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec')
        expect(monthly_progress['Sep']).to eq({full_targets_kwh: '2,220', current_year_kwhs: '1,110', monthly_performance: '77.8'})
      end

      it 'returns cumulative progress' do
        cumulative_progress = service.cumulative_progress

        expect(cumulative_progress.keys).to include('Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec')
        expect(cumulative_progress['Sep']).to eq({full_cumulative_targets_kwhs: '5,560', full_cumulative_current_year_kwhs: '4,440', cumulative_performance: '88.9'})
      end
    end
  end
end
