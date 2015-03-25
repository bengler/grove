module Grove
  module CLI

    module Colorization

      def colorize(message, color, attribute = nil)
        attribute = "#{ANSI_ATTRIBUTES[attribute]};" if attribute
        "\e[#{attribute}#{ANSI_COLORS[color]}m#{message}\e[0m"
      end

      private

        ANSI_COLORS = { 
          none: '0',
          black: '30',
          red: '31',
          green: '32',
          yellow: '33',
          blue: '34',
          magenta: '35',
          cyan: '36',
          white: '37'
        } 

        ANSI_ATTRIBUTES = {
          bright: 1,
          dim: 2,
          underscore: 4,
          blink: 5,
          reverse: 7,
          hidden: 8
        }

    end

  end
end