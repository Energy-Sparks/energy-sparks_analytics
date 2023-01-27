module AnalysableMixin
  # This module provides methods for a consistent interface across the analytics services classes. It's intended to be included and
  # overridden where appropriate.

  def enough_data?
    # This should return true if the service can run the analysis, false otherwise.
    # It should largely just check for data availability, e.g. whether there's a years worth of data, but some implementations
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
