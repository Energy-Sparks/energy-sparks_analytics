require 'erb'

# extension of DashboardEnergyAdvice for heating regression model fitting
class DashboardEnergyAdvice

  def self.solar_pv_advice_factory(chart_type, school, chart_definition, chart_data, chart_symbol)
    case chart_type
    when :solar_pv_group_by_week
      SolarPVVersusIrradianceAdvice.new(school, chart_definition, chart_data, chart_symbol)
    when :solar_pv_group_by_week_by_submeter
      SolarPVMainsVersusSolarPVElectricity.new(school, chart_definition, chart_data, chart_symbol)
    else
      nil
    end
  end


  class SolarPVVersusIrradianceAdvice < WeeklyLongTermAdvice
    def generate_advice
      header_template = %{
        <%= @body_start %>
          <p>
            This chart shows the predicted output of your solar PV panels in kWh, versus
            solar irradiance (2nd Y axis) as measured by a local weather station.
          </p>
        <%= @body_end %>
      }.gsub(/^  /, '')
  
      @header_advice = generate_html(header_template, binding)
  
      footer_template = %{
        <%= @body_start %>
          <p>
            The predicted output of your solar PV panels should follow the irradiance
            as measured by the weather station.
          </p>
        <%= @body_end %>
      }.gsub(/^  /, '')
  
      @footer_advice = generate_html(footer_template, binding)
    end
  end

  class SolarPVMainsVersusSolarPVElectricity < GasDayOfWeekAdvice
    def generate_advice
      header_template = %{
        <%= @body_start %>
          <p>
            This chart shows how much of the electricity you consume onsite comes from
            mains electricity, from the national grid, and how much is consumed from
            your solar panels.
          </p>
        <%= @body_end %>
      }.gsub(/^  /, '')
  
      @header_advice = generate_html(header_template, binding)
  
      footer_template = %{
        <%= @body_start %>
          <p>
            At what time of year do your solar panels contribute most to saving
            you from consuming electricity from the naitonal grid?
          </p>
        <%= @body_end %>
      }.gsub(/^  /, '')
  
      @footer_advice = generate_html(footer_template, binding)
    end
  end

end
