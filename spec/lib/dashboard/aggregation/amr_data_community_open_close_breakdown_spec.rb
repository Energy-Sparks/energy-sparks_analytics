require 'spec_helper'

describe AMRDataCommunityOpenCloseBreakdown do

  let(:meter)        { build(:meter, type: :electricity)}
  let(:holidays)     { build(:holidays, :with_academic_year) }

  let(:school_times) do
    [{day: :monday, usage_type: :school_day, opening_time: TimeOfDay.new(7,30), closing_time: TimeOfDay.new(16,20), calendar_period: :term_times}]
  end

  let(:open_close_times)      { OpenCloseTimes.convert_frontend_times(school_times, community_use_times, holidays)}
  let(:open_close_breakdown)  { AMRDataCommunityOpenCloseBreakdown.new(meter, open_close_times) }

  before do
    meter.amr_data.open_close_breakdown = open_close_breakdown
  end

  describe '#days_kwh_x48' do
    let(:community_use_times)   { [] }
    let(:community_use)         { nil }
    let(:day)                   { Date.today }

    let(:days_kwh_x48)          { open_close_breakdown.days_kwh_x48(day, :kwh, community_use: community_use) }

    context 'with no community use time period' do
      context 'with default filter' do
        it 'returns just an opening and closing time breakdown' do
          expect(days_kwh_x48.keys).to match_array([:school_day_closed, :school_day_open])
          expect(days_kwh_x48.values.all?{ |v| v.size == 48 })
        end

        it 'returns same total as the amr_data class' do
          expect(days_kwh_x48.values.flatten.sum).to be_within(0.0001).of( meter.amr_data.days_kwh_x48(day).sum )
        end
      end
    end

    context 'with single community use time period' do
      let(:community_use_times)          do
        [{day: :monday, usage_type: :community_use, opening_time: TimeOfDay.new(19,00), closing_time: TimeOfDay.new(21,30), calendar_period: :term_times}]
      end

      context 'with default filter' do
        it 'returns a breakdown of all periods' do
          expect(days_kwh_x48.keys).to match_array([:school_day_closed, :school_day_open, :community, :community_baseload])
        end

        it 'returns same total as the amr_data class' do
          expect(days_kwh_x48.values.flatten.sum).to be_within(0.0001).of( meter.amr_data.days_kwh_x48(day).sum )
        end
      end

      context 'with a filter' do
        let(:community_use) do
          {
            filter:    filter,
            aggregate: :none,
            split_electricity_baseload: true
          }
        end

        context 'with :community_only filter' do
          let(:filter)    { :community_only }
          it 'returns a breakdown of just the community use' do
            expect(days_kwh_x48.keys).to match_array([:community, :community_baseload])
          end
        end

        context 'with :school_only filter' do
          let(:filter)    { :school_only }
          it 'returns a breakdown of just the school day' do
            expect(days_kwh_x48.keys).to match_array([:school_day_closed, :school_day_open])
          end
        end

        context 'with :all filter' do
          let(:filter)    { :all }
          it 'returns a breakdown of all periods' do
            expect(days_kwh_x48.keys).to match_array([:school_day_closed, :school_day_open, :community, :community_baseload])
          end

          it 'returns same total as the amr_data class' do
            expect(days_kwh_x48.values.flatten.sum).to be_within(0.0001).of( meter.amr_data.days_kwh_x48(day).sum )
          end
        end
      end

      context 'when aggregating' do
        let(:split_electricity_baseload)  { true }
        #:none is tested in previous specs
        let(:community_use) do
          {
            filter:    :all,
            aggregate: aggregate,
            split_electricity_baseload: split_electricity_baseload
          }
        end

        context 'with :community_use' do
          let(:aggregate) { :community_use }
          context 'when splitting out baseload' do
            xit 'does not apply a sum?' do
              not_aggregated = open_close_breakdown.days_kwh_x48(day, :kwh, community_use: nil)
              expect(days_kwh_x48[:community].sum).to be_within(0.0001).of( not_aggregated[:community].sum )
            end
            it 'includes the baseload' do
              expect(days_kwh_x48.keys).to match_array([:school_day_closed, :school_day_open, :community, :community_baseload])
            end
          end
          context 'when not splitting out baseload' do
            let(:split_electricity_baseload)  { false }

            it 'sums the community use as :community' do
              not_aggregated = open_close_breakdown.days_kwh_x48(day, :kwh, community_use: nil)
              expected_sum = not_aggregated[:community].sum + not_aggregated[:community_baseload].sum
              expect(days_kwh_x48[:community].sum).to be_within(0.0001).of( expected_sum )
            end

            it 'does not include the baseload' do
              expect(days_kwh_x48.keys).to match_array([:school_day_closed, :school_day_open, :community])
            end
          end

        end

        context 'with :all_to_single_value' do
          let(:aggregate) { :all_to_single_value }
          it 'returns an array with same total as the amr_data class' do
            expect(days_kwh_x48.sum).to be_within(0.0001).of( meter.amr_data.days_kwh_x48(day).sum )
          end
        end
      end
    end

    context 'with multiple community use times' do

      let(:community_use_times)          do
        [
          {day: :monday, usage_type: :community_use, opening_time: TimeOfDay.new(6,00), closing_time: TimeOfDay.new(7,30), calendar_period: :term_times},
          {day: :monday, usage_type: :community_use, opening_time: TimeOfDay.new(19,00), closing_time: TimeOfDay.new(21,30), calendar_period: :term_times}
        ]
      end

      context 'with default filter' do
        it 'returns a breakdown of all periods' do
          expect(days_kwh_x48.keys).to match_array([:school_day_closed, :school_day_open, :community, :community_baseload])
        end

        it 'returns same total as the amr_data class' do
          expect(days_kwh_x48.values.flatten.sum).to be_within(0.0001).of( meter.amr_data.days_kwh_x48(day).sum )
        end
      end
    end
  end

  describe '#one_day_kwh' do
  end

  describe '#kwh_date_range' do
  end

  describe '#kwh' do
  end

  describe '#series_names' do
  end
end
