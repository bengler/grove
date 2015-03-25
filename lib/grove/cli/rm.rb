require_relative './colorization'
require_relative './utility'

module Grove
  module CLI

    class Rm

      include Colorization
      include Utility

      def self.build(program)
        program.command :rm do |c|
          c.syntax "rm UID ..."
          c.description "Delete posts"
          c.action do |args, options|
            Rm.new.process(args, options)
          end
        end
      end

      def process(args = [], options = {})
        count = 0
        args.each do |uid|
          puts colorize("Deleting posts", :yellow, :bright)
          scope = scope_from_uid(uid)
          Post.transaction do
            scope.find_each do |post|
              puts colorize("Deleting #{post.uid}", :red)
              post.deleted = true
              post.save!
              count += 1
            end
          end
        end
        puts if count > 0
        puts('%8d posts deleted.' % count)
      end

    end

  end
end
