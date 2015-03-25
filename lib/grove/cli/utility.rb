module Grove
  module CLI
    module Utility

      def scope_from_uid(uid)
        klass, path, id = Pebbles::Uid.parse(uid) if uid

        posts = Post
        posts = posts.where(klass: klass) if klass
        posts = posts.where(id: id) if id
        posts = posts.by_path(path) if path
        posts
      end

      def print_post(post)
        puts
        puts colorize("==== " + colorize(post.uid, :green, :bright) + " ====", :white, :bright)
        print_attributes(post.attributes)
      end

      def print_attributes(hash, hanging_prefix = '')
        longest_key = hash.keys.map(&:length).max
        hash.each_with_index do |(key, value), index|
          print hanging_prefix if index > 0

          formatted_key = key.rjust(longest_key)
          print(colorize(formatted_key, :cyan, :bright))
          print(': ')

          if value.is_a?(Hash) and value.length > 0
            print_attributes(value, hanging_prefix +
              (' ' * formatted_key.length) + ': ')
          else
            print(colorize(value.inspect, :red, :bright))
            puts
          end
        end
      end

    end
  end
end
