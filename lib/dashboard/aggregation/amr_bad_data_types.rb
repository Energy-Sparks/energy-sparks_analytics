class OneDayAMRReading
  # rubocop:enable Metrics/LineLength
  AMR_TYPES = {
    'ORIG'  => { name: 'Original - uncorrected good data'},
    'LGAP'  => { name: 'Too much missing data prior to this date'},
    'CMP1'  => { name: 'Correct partially missing (zero) data on this date - 1 missing'},
    'CMP2'  => { name: 'Correct partially missing (zero) data on this date - 2 missing'},
    'CMP3'  => { name: 'Correct partially missing (zero) data on this date - 3 missing'},
    'CMP4'  => { name: 'Correct partially missing (zero) data on this date - 4 missing'},
    'CMP5'  => { name: 'Correct partially missing (zero) data on this date - 5 missing'},
    'CMP6'  => { name: 'Correct partially missing (zero) data on this date - 6 missing'},
    'DMP1'  => { name: 'Correct partially missing (zero) data on this date - 1 missing'},
    'DMP2'  => { name: 'Correct partially missing (zero) data on this date - 2 missing'},
    'DMP3'  => { name: 'Correct partially missing (zero) data on this date - 3 missing'},
    'DMP4'  => { name: 'Correct partially missing (zero) data on this date - 4 missing'},
    'DMP5'  => { name: 'Correct partially missing (zero) data on this date - 5 missing'},
    'DMP6'  => { name: 'Correct partially missing (zero) data on this date - 6 missing'},
    'CMPH'  => { name: 'Correct partially missing (zero) data on this date'},
    'FIXS'  => { name: 'Setting fixed start date - bad data before'},
    'FIXE'  => { name: 'Setting fixed end date; bad data after/deprecated'},
    'MWKE'  => { name: 'Missing Weekend - set to zero'},
    'MHOL'  => { name: 'Missing Holiday'},
    'MDTZ'  => { name: 'Missing data date range set to zero'},
    'S31M'  => { name: 'Scaled Data: 100ft3 to m2'},
    'GSS1'  => { name: 'Missing gas - substituted school day'},
    'GSW1'  => { name: 'Missing gas - substituted weekend'},
    'GSh1'  => { name: 'Missing gas - substituted weekend/holiday'},
    'GSH1'  => { name: 'Missing gas - substituted holiday'},
    'GXS1'  => { name: 'Override gas - substituted school day'},
    'GXW1'  => { name: 'Override gas - substituted weekend'},
    'GXh1'  => { name: 'Override gas - substituted weekend/holiday'},
    'GXH1'  => { name: 'Override gas - substituted holiday'},
    'GSBH'  => { name: 'Missing gas - substituted holiday'},
    'G0H1'  => { name: 'Missing gas - holiday set to zero'},
    'E0H1'  => { name: 'Missing electricity - holiday set to zero'},
    'ESS1'  => { name: 'Missing electricity - substituted school day'},
    'ESW1'  => { name: 'Missing electricity - substituted weekend'},
    'ESh1'  => { name: 'Missing electricity - substituted weekend/holiday'},
    'ESH1'  => { name: 'Missing electricity - substituted holiday'},
    'EXS1'  => { name: 'Override electricity - substituted school day'},
    'EXW1'  => { name: 'Override electricity - substituted weekend'},
    'EXh1'  => { name: 'Override electricity - substituted weekend/holiday'},
    'EXH1'  => { name: 'Override electricity - substituted holiday'},
    'ESBH'  => { name: 'Missing electricity - substituted holiday'},
    'BGG1'  => { name: 'Gap too big - ignored all previous days'},
    'BGG2'  => { name: 'Gap too big - ignored all previous days'},
    'PROB'  => { name: 'Unable to substitute missing data'},
    'SUMZ'  => { name: 'Missing summer gas heating data set to zero'},
    'ALLZ'  => { name: 'Missing gas data set to zero'},
    'ZMDR'  => { name: 'Set missing data in date range to zero'},
    'ZDTR'  => { name: 'Set bad data in date range to zero'},
    'AGGR'  => { name: 'Aggregate meter data'},
    'STOR'  => { name: 'Extracted storage heater data (good)'},
    'STEX'  => { name: 'Remaining data post storage heater extraction-good'},
    'STRO'  => { name: 'Extracted storage heater data (substituted)'},
    'STXE'  => { name: 'Remaining data post storage heater extraction-subd'},
    'SOLR'  => { name: 'Synthetic solar PV output (good)'},
    'SOLO'  => { name: 'Synthetic solar PV consumed Onsite (good)'},
    'SOLE'  => { name: 'Synthetic solar PV exported (good)'},
    'SOLX'  => { name: 'Synthetic onsite solar + mains consumption (good)'},
    'HSIM'  => { name: 'Synthetic data used on heating/hw calcs'},
    'SOLS'  => { name: 'Overridden PV data with data from Sheffield'},
    'SOL0'  => { name: 'Zero pv generation data prior/post to pv install'},
    'BKPV'  => { name: 'Backfilled PV data (aggregation service)'},
    'TARG'  => { name: 'Synthetic target data'},
    'PSTD'  => { name: 'Partial data for end date - ignoring'},
    'PETD'  => { name: 'Partial data for end date - ignoring'},
    'DCCP'  => { name: 'Partial DCC data for interpolation'},
  }.freeze

  # allow access until front end changes made
  # private_constant :AMR_TYPES

  # duplicate name to description: a bit of a fudge as the original design
  # was to make name a short description, but most end up being the same length
  def self.amr_types
    @@amr_types ||= AMR_TYPES. transform_values { |v| v.key?(:description) ? v : v.merge({ description: v[:name] }) }
  end
  # rubocop:disable Metrics/LineLength
end
