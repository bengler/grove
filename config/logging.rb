require "logger"

Log = LOGGER if defined?(LOGGER)
Log ||= Logger.new(STDOUT)
