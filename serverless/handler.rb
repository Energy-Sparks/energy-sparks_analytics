# frozen_string_literal: true

require 'bundler'
Bundler.setup(:default)

def run(event:, context:)
  s3_record = event['Records'].first['s3']
  file_key = CGI.unescape(s3_record['object']['key'])
  bucket_name = s3_record['bucket']['name']

  logger = Logger.new($stdout)
  logger.info("Running handler: #{handler.name} with file: #{file_key} from bucket: #{bucket_name}")
  logger.debug("Event: #{event}")
  logger.debug("Context: #{context}")
end
