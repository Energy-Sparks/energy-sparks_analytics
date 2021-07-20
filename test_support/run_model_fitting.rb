class RunModelFitting < RunDashboardChartList
  private def excel_variation; '- regression modelling' end
  private def name; 'Running model fitting charts and advice for' end
  private def short_name; 'regression' end
  private def dashboard_config; %i[heating_model_fitting] end
  def meters; @school.all_heat_meters end
end
