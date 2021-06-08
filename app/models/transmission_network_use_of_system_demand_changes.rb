# probably due to be replaced by a fixed charge per day from April 2023
#
class TUOSCharges
  TRIAD_DATES = {
    '2020-2021' => [
        DateTime.new(2020, 12, 7, 17,  0, 0),
        DateTime.new(2021,  1, 7, 17, 30, 0),
        DateTime.new(2021, 10, 7, 18,  0, 0),
    ],
  }

  # https://www.nationalgrideso.com/charging/transmission-network-use-system-tnuos-charges
  FINAL_TUOS_RATES = {
    '2020-2021' => [
      { zone: 1, name: 'Northern Scotland', rate_£_per_kw: 21.126849},
      { zone: 2, name: 'Southern Scotland', rate_£_per_kw: 28.760295},
      { zone: 3, name: 'Northern', rate_£_per_kw: 40.022002},
      { zone: 4, name: 'North West', rate_£_per_kw: 46.674676},
      { zone: 5, name: 'Yorkshire', rate_£_per_kw: 47.83468},
      { zone: 6, name: 'N Wales & Mersey', rate_£_per_kw: 48.904955},
      { zone: 7, name: 'East Midlands', rate_£_per_kw: 51.387929},
      { zone: 8, name: 'Midlands', rate_£_per_kw: 52.648445},
      { zone: 9, name: 'Eastern', rate_£_per_kw: 53.48845},
      { zone: 10, name: 'South Wales', rate_£_per_kw: 50.613794},
      { zone: 11, name: 'South East', rate_£_per_kw: 56.501849},
      { zone: 12, name: 'London', rate_£_per_kw: 59.267002},
      { zone: 13, name: 'Southern', rate_£_per_kw: 57.772417},
      { zone: 14, name: 'South Western', rate_£_per_kw: 57.020402},
    ] 
  }
  # guesswork, https://en.wikipedia.org/wiki/Meter_Point_Administration_Number map
  TUOS_ZONES_TO_MPAN_REGION_MAP = {
     1 => 17,
     2 => 18,
     3 => 15,
     4 => 16, # ? Northern v. North west
     5 => 23,
     6 => 13,
     7 => 11,
     8 => 14, # Midlands versus West midlands?
     9 => 10, 
    10 => 21,
    11 => 19,
    12 => 12,
    13 => 20,
    14 => 22
  }


end