# frozen_string_literal: true

require 'spec_helper'

describe XBucketAcademicYear do
  describe '#create_x_axis' do
    it 'works with incomplete academic years' do
      bucket = described_class.new(nil,
                                   [SchoolDatePeriod.new(nil, nil, Date.new(2023, 9, 1), Date.new(2023, 10, 1)),
                                    SchoolDatePeriod.new(nil, nil, Date.new(2023, 1, 1), Date.new(2023, 8, 1))])
      bucket.create_x_axis
      expect(bucket.x_axis).to eq(['Academic Year 23/24', 'Academic Year 22/23'])
    end
  end
end
