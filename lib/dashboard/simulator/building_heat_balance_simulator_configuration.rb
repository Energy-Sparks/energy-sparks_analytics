class BuildingHeatBalanceSimulatorConfiguration

  def initialize(school)
    @config = BuildingHeatBalanceSimulatorConfiguration.all_configs[school.urn]
    @school = school
  end

  def wall_heat_loss_w_per_k
    @config[:buildings].values.map do |building|
      gross_area = building.dig(:walls, :area) ||
        (2.5 * 4.0 * (building[:floor_area] / building[:storeys]) ** 0.5)
      window_area = building.dig(:windows, :area) || gross_area * 0.2
      area = gross_area - window_area
      area * (building.dig(:walls, :u) || 1.0)
    end.sum # have to use map, then sum due to Statsample sum bug
  end

  def net_wall_area_m2
    gross_wall_area_m2 - window_area_m2
  end

  def gross_wall_area_m2
    @config[:buildings].values.map do |building|
      building.dig(:walls, :area) ||
        (2.5 * 4.0 * (building[:floor_area] / building[:storeys]) ** 0.5)
    end.sum # have to use map, then sum due to Statsample sum bug
  end

  def window_area_m2
    @config[:buildings].values.map do |building|
      building.dig(:windows, :area) || gross_wall_area_m2 * 0.2
    end.sum # have to use map, then sum due to Statsample sum bug
  end

  def self.school_config(school)
    BuildingHeatBalanceSimulatorConfiguration.new(school)
  end

  def self.all_configs
    @configs ||= create_config
  end

  # create dynamically rather than at compile time via constant
  def self.create_config
    {
      8002236 => { # Bathampton Primary
        meters: {
          16642504 => {
            'main school' => {
              heating_weight:   1.0,
              hot_water_weight: 1.0
            }
          }
        },
        buildings: {
          'main school' =>  {
            floor_area: 1000.0,
            form_factor: 1.4,
            storeys: 1,
            walls: {
              u:    1.5
            },
            roof: {
              u:    1.5
            },
            windows: {
              area: 70.0,
              u_w: 2.5,
              g_value: 0.6,
              f_factor: 0.8
            },
            { mpan: 16642504 } => 1.0
          },
        },
      },
    }
  end
end