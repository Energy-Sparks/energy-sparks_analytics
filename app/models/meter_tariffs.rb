require_relative '../../lib/dashboard/time_of_year.rb'
require_relative '../../lib/dashboard/time_of_day.rb'
require 'awesome_print'
require 'date'
# tariff information on a per school basis, part of meter attributes infrastructure
# but held in a seperate file and class for clarity
#
class MeterTariffs
  extend Logging

  @@cached_meter_tariff = Hash.new { |hash, key| hash[key] = {} } # [mprn/mpan][economic|accounting tariff ] = tariff object

  def self.price_tariff(meter_collection, meter, tariff_type)
    # have we already created a tariff object for this tariff?
    cached_tariff = @@cached_meter_tariff.dig(meter.mpan_or_mprn, tariff_type)
    return cached_tariff unless cached_tariff.nil?

    tariff = create_tariff(meter_collection, meter.mpan_or_mprn, tariff_type)
    @@cached_meter_tariff[meter.mpan_or_mprn][tariff_type] = tariff
  end

  def self.create_tariff(meter_collection, mpan_or_mprn, tariff_type)
    specific_tariff = METER_TARIFFS.dig(meter.mpan_or_mprn, tariff_type)
    return tariff_factory(specific_tariff) unless specific_tariff.nil?

    # if its an economic tariff check whether accounting tariff suggests it should be

    area = meter_collection.area_name
    specific_tariff = METER_TARIFFS.dig(meter.mpan_or_mprn, tariff_type)
    return specific_tariff unless specific_tariff.nil?

  end

  def self.accounting_tariff?(mpan_or_mprn)
    !METER_TARIFFS.dig(meter.mpan_or_mprn, :accounting_tariffs).nil?
  end

  GROUP_TARIFFS = {
    'All' => {
      economic_tariffs: {
        electricity:  {
          flat_rate_£_per_kwh: 0.12,
          rate_type: :flat
        },
        electricity_differential: {
          name: 'Differential economic tariff (e.g. economy 7)',
          rate_type: :differential,
          differential_rate_£_per_kwh: {
            TimeOfDay.new(0,0)..TimeOfDay.new(6,30) => 0.08,
            TimeOfDay.new(7,0)..TimeOfDay.new(24,0) => 0.13
          }
        },
        gas: {
          flat_rate_£_per_kwh: 0.03,
          rate_type: :flat
        }
      }
    },
    'Bath' => {
      electricity: {
        accounting_tariffs: {
          Date.new(2009,1,1)..Date.new(2020,3,1) => {
            name: 'B&NES day-night electricity tariff',
            rate_type: :differential,
            standing_charge_£_per_quarter:		38.35,
            renewable_energy_obligation_fit_£_per_kwh: 0.00565,
            differential_rate_£_per_kwh: { TimeOfDay.new(0,0)..TimeOfDay.new(6,30) => 0.08736, TimeOfDay.new(7,0)..TimeOfDay.new(24,0) => 0.12805}
          }
        }
      },
      gas: {
      }
    },
    'Sheffield' => {
      electricity: {
        Date.new(2017,1,1)..Date.new(2020,3,1) => {
          name: 'Npower YPO 5 year electricity plan - default - shouldnt really exist as all deals seem bespoke',
          rate_type: :flat,
          standing_charge_£_per_day:		6.00,
          capacity_charge_£_per_month:		0.0,
          flat_rate_£_per_kwh:  0.12
        }
      },
      gas: {
      }
    }
  }.freeze
  private_constant :GROUP_TARIFFS

  # meter specific tariffs, where tariff is unique to the meter
  # typically 'accounting tariffs', and perhaps ultimately
  # solar tariffs where there is a bespoke FIT rate?
  METER_TARIFFS = {

    # =========Bankwood Primary School========
    2333110019718 =>  {
      accounting_tariffs: {
        Date.new(2017,1,1)..Date.new(2020,3,1) => {
          name: 'Npower YPO 5 year electricity plan - flat rate',
          rate_type: :flat,
          standing_charge_£_per_day:		6.161,
          capacity_charge_£_per_month:		0.0,
          flat_rate_£_per_kwh:  0.1191,
        }
      }
    },
  
  # =========Coit Primary School========
    2332951462710 =>  {
      accounting_tariffs: {
        Date.new(2017,1,1)..Date.new(2020,3,1) => {
          name: 'Npower YPO 5 year electricity plan - flat rate',
          rate_type: :flat,
          standing_charge_£_per_day:		6.161,
          capacity_charge_£_per_month:		0.0,
          flat_rate_£_per_kwh:  0.1191,
        }
      }
    },
  
  	2332951460713 =>  {
      accounting_tariffs: {
        Date.new(2017,1,1)..Date.new(2020,3,1) => {
          name: 'Npower YPO 5 year electricity plan - differential rate',
          rate_type: :differential,
          standing_charge_£_per_day:		6.161,
          capacity_charge_£_per_month:		0.0,
          differential_rate_£_per_kwh: { TimeOfDay.new(0,0)..TimeOfDay.new(6,30) => 0.08975,TimeOfDay.new(7,0)..TimeOfDay.new(24,0) => 0.12696}
        }
      }
    },
  
  # =========Ecclesfield Primary School========
    2332531911711 =>  {
      accounting_tariffs: {
        Date.new(2017,1,1)..Date.new(2020,3,1) => {
          name: 'Npower YPO 5 year electricity plan - differential rate',
          rate_type: :differential,
          standing_charge_£_per_day:		6.161,
          capacity_charge_£_per_month:		0.0,
          differential_rate_£_per_kwh: { TimeOfDay.new(0,0)..TimeOfDay.new(6,30) => 0.08975,TimeOfDay.new(7,0)..TimeOfDay.new(24,0) => 0.12696}
        }
      }
    },
  
  # =========Mundella Primary School========
    2333202372710 =>  {
      accounting_tariffs: {
        Date.new(2017,1,1)..Date.new(2020,3,1) => {
          name: 'Npower YPO 5 year electricity plan - flat rate',
          rate_type: :flat,
          standing_charge_£_per_day:		6.161,
          capacity_charge_£_per_month:		0.0,
          flat_rate_£_per_kwh:  0.1191,
        }
      }
    },
  
  	2380001727391 =>  {
      accounting_tariffs: {
        Date.new(2017,1,1)..Date.new(2020,3,1) => {
          name: 'Npower YPO 5 year electricity plan - differential rate',
          rate_type: :differential,
          standing_charge_£_per_day:		6.161,
          capacity_charge_£_per_month:		0.0,
          differential_rate_£_per_kwh: { TimeOfDay.new(0,0)..TimeOfDay.new(6,30) => 0.08975,TimeOfDay.new(7,0)..TimeOfDay.new(24,0) => 0.12696}
        }
      }
    },
  
  
  # =========Walkley School Tennyson School========
    2330621110711 =>  {
      accounting_tariffs: {
        Date.new(2017,1,1)..Date.new(2020,3,1) => {
          name: 'Npower YPO 5 year electricity plan - flat rate',
          rate_type: :flat,
          standing_charge_£_per_day:		6.161,
          capacity_charge_£_per_month:		0.0,
          flat_rate_£_per_kwh:  0.1191,
        }
      }
    },
  
  	2330605147010 =>  {
      accounting_tariffs: {
        Date.new(2017,1,1)..Date.new(2020,3,1) => {
          name: 'Npower YPO 5 year electricity plan - differential rate',
          rate_type: :differential,
          standing_charge_£_per_day:		6.161,
          capacity_charge_£_per_month:		0.0,
          differential_rate_£_per_kwh: { TimeOfDay.new(0,0)..TimeOfDay.new(6,30) => 0.08975,TimeOfDay.new(7,0)..TimeOfDay.new(24,0) => 0.12696}
        }
      }
    },
  
  # =========Woodthorpe Primary School========
    2380000477230 =>  {
      accounting_tariffs: {
        Date.new(2017,1,1)..Date.new(2020,3,1) => {
          name: 'Npower YPO 5 year electricity plan - differential rate',
          rate_type: :differential,
          standing_charge_£_per_day:		4.064,
          capacity_charge_£_per_month:		0.38,
          differential_rate_£_per_kwh: { TimeOfDay.new(0,0)..TimeOfDay.new(6,30) => 0.08826,TimeOfDay.new(7,0)..TimeOfDay.new(24,0) => 0.11684}
        }
      }
    },
  
  # =========Wybourn Primary School========
    2331301835711 =>  {
      accounting_tariffs: {
        Date.new(2017,1,1)..Date.new(2020,3,1) => {
          name: 'Npower YPO 5 year electricity plan - differential rate',
          rate_type: :differential,
          standing_charge_£_per_day:		4.064,
          capacity_charge_£_per_month:		0.38,
          differential_rate_£_per_kwh: { TimeOfDay.new(0,0)..TimeOfDay.new(6,30) => 0.08826,TimeOfDay.new(7,0)..TimeOfDay.new(24,0) => 0.11897}
        }
      }
    },
  
  
  # =========Whiteways Primary========
    2334501345714 =>  {
      accounting_tariffs: {
        Date.new(2017,1,1)..Date.new(2020,3,1) => {
          name: 'Npower YPO 5 year electricity plan - flat rate',
          rate_type: :flat,
          standing_charge_£_per_day:		6.161,
          capacity_charge_£_per_month:		0.0,
          flat_rate_£_per_kwh:  0.1191,
        }
      }
    },
  
  # =========Ecclesall Primary (Previously named 'Infants')========
    2331031705716 =>  {
      accounting_tariffs: {
        Date.new(2017,1,1)..Date.new(2020,3,1) => {
          name: 'Npower YPO 5 year electricity plan - differential rate',
          rate_type: :differential,
          standing_charge_£_per_day:		6.161,
          capacity_charge_£_per_month:		0.0,
          differential_rate_£_per_kwh: { TimeOfDay.new(0,0)..TimeOfDay.new(6,30) => 0.08975,TimeOfDay.new(7,0)..TimeOfDay.new(24,0) => 0.12696}
        }
      }
    },
  
  # =========Hunters Bar Infants and Juniors========
    2336531952014 =>  {
      accounting_tariffs: {
        Date.new(2017,1,1)..Date.new(2020,3,1) => {
          name: 'Npower YPO 5 year electricity plan - differential rate',
          rate_type: :differential,
          standing_charge_£_per_day:		6.161,
          capacity_charge_£_per_month:		0.0,
          differential_rate_£_per_kwh: { TimeOfDay.new(0,0)..TimeOfDay.new(6,30) => 0.08975,TimeOfDay.new(7,0)..TimeOfDay.new(24,0) => 0.12696}
        }
      }
    },
  
  
  
  
  # =========Watercliffe Meadow Community Primary School========
    2380001112280 =>  {
      accounting_tariffs: {
        Date.new(2017,1,1)..Date.new(2020,3,1) => {
          name: 'Npower YPO 5 year electricity plan - differential rate',
          rate_type: :differential,
          standing_charge_£_per_day:		4.064,
          capacity_charge_£_per_month:		0.38,
          differential_rate_£_per_kwh: { TimeOfDay.new(0,0)..TimeOfDay.new(6,30) => 0.08824,TimeOfDay.new(7,0)..TimeOfDay.new(24,0) => 0.11763}
        }
      }
    },
  
  # =========Athelstan Primary School========
    2335212561712 =>  {
      accounting_tariffs: {
        Date.new(2017,1,1)..Date.new(2020,3,1) => {
          name: 'Npower YPO 5 year electricity plan - flat rate',
          rate_type: :flat,
          standing_charge_£_per_day:		6.161,
          capacity_charge_£_per_month:		0.0,
          flat_rate_£_per_kwh:  0.1191,
        }
      }
    },
  
  # =========Ballifield Primary School========
    2335250725714 =>  {
      accounting_tariffs: {
        Date.new(2017,1,1)..Date.new(2020,3,1) => {
          name: 'Npower YPO 5 year electricity plan - differential rate',
          rate_type: :differential,
          standing_charge_£_per_day:		6.161,
          capacity_charge_£_per_month:		0.0,
          differential_rate_£_per_kwh: { TimeOfDay.new(0,0)..TimeOfDay.new(6,30) => 0.08975,TimeOfDay.new(7,0)..TimeOfDay.new(24,0) => 0.12696}
        }
      }
    },
  
  # =========Lydgate Junior school========
    2330741676714 =>  {
      accounting_tariffs: {
        Date.new(2017,1,1)..Date.new(2020,3,1) => {
          name: 'Npower YPO 5 year electricity plan - differential rate',
          rate_type: :differential,
          standing_charge_£_per_day:		6.161,
          capacity_charge_£_per_month:		0.0,
          differential_rate_£_per_kwh: { TimeOfDay.new(0,0)..TimeOfDay.new(6,30) => 0.08975,TimeOfDay.new(7,0)..TimeOfDay.new(24,0) => 0.12696}
        }
      }
    },
  
  # =========Arbourthorne Community Primary========
    2380000442901 =>  {
      accounting_tariffs: {
        Date.new(2017,1,1)..Date.new(2020,3,1) => {
          name: 'Npower YPO 5 year electricity plan - differential rate',
          rate_type: :differential,
          standing_charge_£_per_day:		4.064,
          capacity_charge_£_per_month:		0.38,
          differential_rate_£_per_kwh: { TimeOfDay.new(0,0)..TimeOfDay.new(6,30) => 0.08826,TimeOfDay.new(7,0)..TimeOfDay.new(24,0) => 0.1201}
        }
      }
    },
  
  # =========King Edwards Upper========
    2380001640466 =>  {
      accounting_tariffs: {
        Date.new(2017,1,1)..Date.new(2020,3,1) => {
          name: 'Npower YPO 5 year electricity plan - differential rate',
          rate_type: :differential,
          standing_charge_£_per_day:		4.064,
          capacity_charge_£_per_month:		0.38,
          differential_rate_£_per_kwh: { TimeOfDay.new(0,0)..TimeOfDay.new(6,30) => 0.08823,TimeOfDay.new(7,0)..TimeOfDay.new(24,0) => 0.11634}
        }
      }
    },
  
  	2330400572210 =>  {
      accounting_tariffs: {
        Date.new(2017,1,1)..Date.new(2020,3,1) => {
          name: 'Npower YPO 5 year electricity plan - flat rate',
          rate_type: :flat,
          standing_charge_£_per_day:		6.076,
          capacity_charge_£_per_month:		0.0,
          flat_rate_£_per_kwh:  0.1246,
        }
      }
    },
  
  
  # =========Ecclesall Primary (Previously named 'Infants')========
	2155853706 =>  {
		accounting_tariffs: {
			Date.new(2017,1,1)..Date.new(2020,3,1) => {
				name:  'Corona Sheffield YPO 5 year gas plan',
				rate_type: :flat,
				standing_charge_£_per_day:		4.24,
				flat_rate_£_per_kwh:  0.020422
			}
		}
	},

# =========Hunters Bar Infants and Juniors========
	6511808 =>  {
		accounting_tariffs: {
			Date.new(2017,1,1)..Date.new(2020,3,1) => {
				name:  'Corona Sheffield YPO 5 year gas plan',
				rate_type: :flat,
				standing_charge_£_per_day:		2.19,
				flat_rate_£_per_kwh:  0.020422
			}
		}
	},

	6511101 =>  {
		accounting_tariffs: {
			Date.new(2017,1,1)..Date.new(2020,3,1) => {
				name:  'Corona Sheffield YPO 5 year gas plan',
				rate_type: :flat,
				standing_charge_£_per_day:		4.76,
				flat_rate_£_per_kwh:  0.020422
			}
		}
	},

	6512204 =>  {
		accounting_tariffs: {
			Date.new(2017,1,1)..Date.new(2020,3,1) => {
				name:  'Corona Sheffield YPO 5 year gas plan',
				rate_type: :flat,
				standing_charge_£_per_day:		1.25,
				flat_rate_£_per_kwh:  0.020422
			}
		}
	},

	9334657704 =>  {
		accounting_tariffs: {
			Date.new(2017,1,1)..Date.new(2020,3,1) => {
				name:  'Corona Sheffield YPO 5 year gas plan',
				rate_type: :flat,
				standing_charge_£_per_day:		1.26,
				flat_rate_£_per_kwh:  0.020422
			}
		}
	},

# =========Watercliffe Meadow Community Primary School========
	9209120604 =>  {
		accounting_tariffs: {
			Date.new(2017,1,1)..Date.new(2020,3,1) => {
				name:  'Corona Sheffield YPO 5 year gas plan',
				rate_type: :flat,
				standing_charge_£_per_day:		3.75,
				flat_rate_£_per_kwh:  0.020422
			}
		}
	},

# =========Athelstan Primary School========
	2148244308 =>  {
		accounting_tariffs: {
			Date.new(2017,1,1)..Date.new(2020,3,1) => {
				name:  'Corona Sheffield YPO 5 year gas plan',
				rate_type: :flat,
				standing_charge_£_per_day:		7.4,
				flat_rate_£_per_kwh:  0.020422
			}
		}
	},

# =========Ballifield Primary School========
	6508101 =>  {
		accounting_tariffs: {
			Date.new(2017,1,1)..Date.new(2020,3,1) => {
				name:  'Corona Sheffield YPO 5 year gas plan',
				rate_type: :flat,
				standing_charge_£_per_day:		7.15,
				flat_rate_£_per_kwh:  0.020422
			}
		}
	},

# =========Lydgate Junior school========
	6396610 =>  {
		accounting_tariffs: {
			Date.new(2017,1,1)..Date.new(2020,3,1) => {
				name:  'Corona Sheffield YPO 5 year gas plan',
				rate_type: :flat,
				standing_charge_£_per_day:		5.3,
				flat_rate_£_per_kwh:  0.020422
			}
		}
	},

# =========Arbourthorne Community Primary========
	9124298109 =>  {
		accounting_tariffs: {
			Date.new(2017,1,1)..Date.new(2020,3,1) => {
				name:  'Corona Sheffield YPO 5 year gas plan',
				rate_type: :flat,
				standing_charge_£_per_day:		10.63,
				flat_rate_£_per_kwh:  0.020422
			}
		}
	},

# =========King Edwards Upper========
	6516504 =>  {
		accounting_tariffs: {
			Date.new(2017,1,1)..Date.new(2020,3,1) => {
				name:  'Corona Sheffield YPO 5 year gas plan',
				rate_type: :flat,
				standing_charge_£_per_day:		0.86,
				flat_rate_£_per_kwh:  0.020422
			}
		}
	},

	6517203 =>  {
		accounting_tariffs: {
			Date.new(2017,1,1)..Date.new(2020,3,1) => {
				name:  'Corona Sheffield YPO 5 year gas plan',
				rate_type: :flat,
				standing_charge_£_per_day:		16.77,
				flat_rate_£_per_kwh:  0.020422
			}
		}
	},

	9306413207 =>  {
		accounting_tariffs: {
			Date.new(2017,1,1)..Date.new(2020,3,1) => {
				name:  'Corona Sheffield YPO 5 year gas plan',
				rate_type: :flat,
				standing_charge_£_per_day:		1.56,
				flat_rate_£_per_kwh:  0.020422
			}
		}
	},

  }.freeze
  private_constant :METER_TARIFFS

end
