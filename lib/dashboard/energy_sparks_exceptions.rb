class EnergySparksBadDataException < StandardError
  # def initialize(message)
  #   super.initialize(message)
  # end
end

class EnergySparksUnexpectedStateException < StandardError
end

class EnergySparksUnexpectedSchoolDataConfiguration < StandardError
end

class EnergySparksBadAMRDataTypeException < StandardError
end

class EnergySparksMissingPeriodForSpecifiedPeriodChart < StandardError
end

class EnergySparksBadChartSpecification < StandardError
end

class EnergySparksMeterSpecification < StandardError
end
