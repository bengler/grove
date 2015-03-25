require_relative './colorization'
require_relative './utility'

module Grove
  module CLI

    class Ls

      include Colorization
      include Utility

      def self.build(program)
        program.command :ls do |c|
          c.syntax "ls UID ..."
          c.description "List posts"
          c.option :limit, '-l LIMIT', '--limit LIMIT', 'Limit number of results.'
          c.action do |args, options|
            Ls.new.process(args, options)
          end
        end
      end

      def process(args = [], options = {})
        count, limit = 0, options[:limit]

        args.each do |uid|
          scope = scope_from_uid(uid)
          puts colorize("Listing posts", :yellow, :bright)
          if limit
            posts = scope.limit(limit).to_a
            posts.each do |post|
              print_post(post)
              count += 1
            end
            limit -= posts.length
          else
            scope.find_each do |post|
              print_post(post)
              count += 1
            end
          end
        end

        puts if count > 0
        puts('%8d posts found.' % count)
      end

    end

  end
end
