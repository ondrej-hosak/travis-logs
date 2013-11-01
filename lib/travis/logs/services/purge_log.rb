require "travis/logs/helpers/metrics"
require "travis/logs/helpers/s3"

module Travis
  module Logs
    module Services
      class PurgeLog
        include Helpers::Metrics

        METRIKS_PREFIX = "logs.purge"

        def self.metriks_prefix
          METRIKS_PREFIX
        end

        def initialize(log_id, storage_service = Helpers::S3.new, database = Travis::Logs.database_connection)
          @log_id = log_id
          @database = database
          @storage_service = storage_service
        end

        def run
          if content.nil?
            if content_length.nil?
              Travis.logger.warn("Log with id:#{@log_id} missing in database or on S3")
            else
              @database.mark_archive_verified(@log_id)
              @database.mark_purged(@log_id)
            end
          else
            if content_length == content.length
              @database.clear_log_content(@log_id)
              @database.mark_purged(@log_id)
            end
          end
        end

        private

        def content
          log[:content]
        end

        def content_length
          @storage_service.content_length(log_url)
        end

        def log
          unless defined?(@log)
            @log = @database.log_for_id(@log_id)
            unless @log
              Travis.logger.warn("[warn] log with id:#{@log_id} could not be found")
              mark("log.not_found")
            end
          end

          @log
        end

        def log_url
          "http://#{Travis.config.s3.hostname}/jobs/#{log[:job_id]}/log.txt"
        end
      end
    end
  end
end
