namespace :testing do

  desc 'initialise test harness directories'
  task :init do
    FileUtils.mkdir_p('log')
    if ENV['ANALYTICSTESTDIR']
      FileUtils.mkdir_p(ENV['ANALYTICSTESTDIR'])
      FileUtils.mkdir_p(File.join(ENV['ANALYTICSTESTDIR'], 'MeterCollections'))
    else
      fail "Set the ANALYTICSTESTDIR environment variable and re-run"
    end
  end

  desc 'delete contents of the New, Results and log directories'
  task :clean_results do
    if ENV['ANALYTICSTESTDIR']
      ['New', 'Results', 'log'].each do |dir|
        Rake::Cleaner.cleanup_files(FileList["#{ENV['ANALYTICSTESTDIR']}/*/#{dir}/*"])
      end
    end
  end

  desc 'delete contents of the New directories'
  task :clean_new do
    if ENV['ANALYTICSTESTDIR']
      Rake::Cleaner.cleanup_files(FileList["#{ENV['ANALYTICSTESTDIR']}/*/New/*"])
    end
  end

  desc 'delete contents of the Base directories'
  task :clean_base do
    if ENV['ANALYTICSTESTDIR']
      Rake::Cleaner.cleanup_files(FileList["#{ENV['ANALYTICSTESTDIR']}/*/Base/*"])
    end
  end

  desc 'delete all recent and previous outputs'
  task :clean_outputs => [:clean_results, :clean_base]

  desc 'delete EVERYTHING in the test directory, including data'
  task :clobber do
    if ENV['ANALYTICSTESTDIR']
      Rake::Cleaner.cleanup_files(FileList["#{ENV['ANALYTICSTESTDIR']}/**/*"])
    end
  end

  desc 'copy Base to New'
  task :copy_new_to_base do
    if ENV['ANALYTICSTESTDIR']
      Dir.glob("#{ENV['ANALYTICSTESTDIR']}/*").each do |dir|
        $stderr.puts "Copying #{dir}/New to /Base"
        FileUtils.cp_r "#{dir}/New/.", "#{dir}/Base" if File.directory?("#{dir}/New")
      end
    end
  end

  desc 'download unvalidated data, specify school name prefix with parameter'
  task :download_unvalidated_data, :schools do |t,args|
    fail "Set test directory and bucket environment variables" unless ENV["ANALYTICSTESTDIR"] && ENV['UNVALIDATED_SCHOOL_CACHE_BUCKET']
    require 'aws-sdk-s3'
    args.with_defaults(schools: '')
    bucket = ENV['UNVALIDATED_SCHOOL_CACHE_BUCKET']
    $stderr.puts "Downloading list of files from #{bucket}"
    client = Aws::S3::Client.new
    resp = client.list_objects_v2({
        bucket: bucket,
        prefix: "unvalidated-data-" + args.schools,
    })
    resp.contents.each do |entry|
      filename = "#{ENV['ANALYTICSTESTDIR']}/MeterCollections/#{entry.key}"
      $stderr.puts "Saving data to #{filename}"
      File.open(filename, 'w') do |file|
        resp = client.get_object({ bucket: bucket, key: entry.key }, target: file)
      end
    end
  end
end
