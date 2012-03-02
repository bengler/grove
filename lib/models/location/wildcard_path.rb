module WildcardPath

  class << self

    def is_it?(path)
      path =~ /[\*\|\^]/
    end

    def valid?(path)
      stars_are_solitary?(path) && pipes_are_interleaved?(path) && carets_are_leading?(path) && stars_are_terminating?(path)
    end

    # a.*.c is valid
    # a.*b.c is not
    def stars_are_solitary?(path)
      !path.split('.').any? {|s| s.match(/.+\*|\*.+/)}
    end

    # a.b|c.d is valid
    # a.|b.c is not
    def pipes_are_interleaved?(path)
      !path.split('.').any? {|s| s.match(/^\||\|$/)}
    end

    # a.^b.c is valid
    # a.b^c.d is not
    def carets_are_leading?(path)
      !path.split('.').any? {|s| s.match(/.+\^|\^$/) }
    end

    # a.b.* is valid
    # *.b.c is not
    def stars_are_terminating?(path)
      path !~ /.*\*\.\w/
    end

  end
end
