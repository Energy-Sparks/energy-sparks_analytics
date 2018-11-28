class OneDayAMRReading
  # rubocop:enable Metrics/LineLength
  AMR_TYPES = {
    'ORIG'  => { name: 'Original - uncorrected good data',                  description: 'Good quality original reading'},
    'LGAP'  => { name: 'Too much missing data prior to this date',          description: 'Prior data including this day ignored'},
    'CMP1'  => { name: 'Correct partially missing (zero) data on this date',description: 'Electricity data but some zero, not PV, interpolated missing'},
    'CMP2'  => { name: 'Correct partially missing (zero) data on this date',description: 'Electricity data but some zero, not PV, substituted whole day'},
    'FIXS'  => { name: 'Setting fixed start date - bad data before',        description: 'Prior data before date ignored'},
    'MWKE'  => { name: 'Missing Weekend - set to zero',                     description: 'Missing data replaced with zeros'},
    'MHOL'  => { name: 'Missing Holiday',                                   description: 'Missing data replaced with zeros'},
    'MDTZ'  => { name: 'Missing data date range set to zero',               description: 'Missing data replaced with zeros'},
    'S31M'  => { name: 'Scaled Data: 100ft3 to m2',                         description: 'Data from original source in wrong units'},
    'GSS1'  => { name: 'Missing gas - substituted school day',              description: 'Missing gas school day substituted with DD adjustment'},
    'GSW1'  => { name: 'Missing gas - substituted weekend',                 description: 'Missing gas weekend substituted with DD adjustment'},
    'GSh1'  => { name: 'Missing gas - substituted weekend/holiday',         description: 'Missing gas weekend substituted with DD adjustment'},
    'GSH1'  => { name: 'Missing gas - substituted holiday',                 description: 'Missing gas holiday substituted with DD adjustment'},
    'GSBH'  => { name: 'Missing gas - substituted holiday',                 description: 'Missing gas holiday substituted with DD adjustment'},
    'G0H1'  => { name: 'Missing gas - holiday set to zero',                 description: 'Missing gas holiday substituted 0.0'},
    'E0H1'  => { name: 'Missing electricity - holiday set to zero',         description: 'Missing electricity holiday substituted 0.0'},
    'ESS1'  => { name: 'Missing electricity - substituted school day',      description: 'Missing electricity school day substituted'},
    'ESW1'  => { name: 'Missing electricity - substituted weekend',         description: 'Missing electricity weekend substituted'},
    'ESh1'  => { name: 'Missing electricity - substituted weekend/holiday', description: 'Missing electricity weekend substituted'},
    'ESH1'  => { name: 'Missing electricity - substituted holiday',         description: 'Missing electricity holiday substituted'},
    'ESBH'  => { name: 'Missing electricity - substituted holiday',         description: 'Missing electricity holiday substituted'},
    'BGG1'  => { name: 'Gap too big - ignored all previous days',           description: 'Too big a gap (30 days) ignoring all days prior'},
    'BGG2'  => { name: 'Gap too big - ignored all previous days',           description: 'Too big a gap (50 days) ignoring all days prior'},
    'PROB'  => { name: 'Unable to substitute missing data',                 description: 'Setting data to 0.0123456  - dummy value'},
    'SUMZ'  => { name: 'Missing summer gas heating data set to zero',       description: 'Missing heating only meter data set to zero in summer'},
    'ALLZ'  => { name: 'Missing gas data set to zero',                      description: 'Set all data to zero'},
    'ZMDR'  => { name: 'Set missing data in date range to zero',            description: 'Set missing data in date range to zero'},
    'ZDTR'  => { name: 'Set bad data in date range to zero',                description: 'Set bad data in date range to zero'}
  }.freeze
  # rubocop:disable Metrics/LineLength
end
