module WildcardPath

  class << self
    def valid?(path)
      return false unless terminating_star?(path)
      return false unless pipes_separate_options?(path)
      !path.split('.').any? {|s| s.match(/\^$/) }
    end

    def terminating_star?(path)
      path !~ /.*\*\.\w/
    end

    def pipes_separate_options?(path)
      !path.split('.').any? {|s| s.match(/^\||\|$/)}
    end

  end

end
