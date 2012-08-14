require "logger"

Log = LOGGER if defined?(LOGGER)
Log ||= Logger.new(STDOUT)

ActiveRecord::Base.logger.level = Logger::WARN if ActiveRecord::Base.logger