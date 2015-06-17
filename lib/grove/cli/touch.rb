require_relative './colorization'
require_relative './utility'

module Grove
  module CLI

    class Touch

      include Colorization
      include Utility

      def self.build(program)
        program.command :touch do |c|
          c.syntax "touch UID ..."
          c.description "Touch posts"
          c.action do |args, options|
            Touch.new.process(args, options)
          end
        end
      end

      def process(args = [], options = {})
        if args == ['all']
          touch_all_posts!
        else
          count = 0
          args.each do |uid|
            puts colorize("Touching posts", :yellow, :bright)
            scope = scope_from_uid(uid)
            Post.transaction do
              scope.find_each do |post|
                puts colorize("Touching #{post.uid}", :red)
                post.updated_at = Time.now
                post.save!
                count += 1
              end
            end
          end
          puts if count > 0
          puts('%8d posts touched.' % count)
        end
      end


      def touch_all_posts!(batch_size = 512)
        ids = Post.order('created_at DESC').pluck(:id)
        num = ids.count
        puts colorize("Total: #{num}", :red, :bright)

        count = 0
        percent = 0
        previous_message = 0
        ids.each_slice(batch_size) do |chunk|
          Post.find(chunk).each do |post|
            post.updated_at = Time.now
            post.save!
            count += 1
            message = "#{format("%.2f", (count * 100.0 / num))}%"
            if message != previous_message
              print "\b" * message.length
              print colorize(message, :yellow, :bright)
            end
            previous_message = message
          end
        end;nil
      end

    end

  end
end
