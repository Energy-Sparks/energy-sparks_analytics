module AnalysableMixin
  # This module provides methods so we can provide a consistent interface for the analytics services. We need to provide methods on every class:
  # - they have enough data to generate an output (as far as can be determined without actually running the analysis)
  # - if they don't have enough data, some idea of when there will be enough data for that school (assuming we continue to get regular updates).
  # This module is intended to be included in all main service classes to provide defaults and are intended to be superceded where appriate.

  def enough_data?
    # This should return true if the service can run the analysis, false otherwise.
    # It Should largely just check for data availability, e.g. whether there's a years worth of data, but some implementations
    # may also check whether we can construct a valid heating model
  	true
  end

  def data_available_from
    # This should return an estimated Date when there ought to be enough data for the analysis. e.g. if the code requires a years
    # worth of data, then it should work out from the relevant amr_data when a year will be available. If the date can't be determined,
    # or if there are other issues (e.g. we can't generate a model) then return nil
  	nil
  end
end
