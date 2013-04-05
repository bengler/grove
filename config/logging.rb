require "logger"

unless defined?(LOGGER)
  LOGGER = Logger.new("/dev/null")
end

ActiveRecord::Base.logger.level = Logger::WARN if ActiveRecord::Base.logger