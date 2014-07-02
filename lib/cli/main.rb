module Grove
  module CLI

    class Main < ::Thor

      include Colorization

      desc 'ls UID', 'List posts'
      method_option :limit,
        type: :numeric,
        aliases: "-l",
        desc: "Limit number of results"
      def ls(uid = nil)
        count = 0

        scope = scope_from_uid(uid)

        puts colorize("Listing posts", :yellow, :bright)
        if options[:limit]
          posts = scope.limit(options[:limit]).to_a
          posts.each do |post|
            print_post(post)
            count += 1
          end
        else
          scope.find_each do |post|
            print_post(post)
            count += 1
          end
        end
        puts if count > 0
        puts('%8d posts found.' % count)
      end

      desc 'rm UID', 'Delete posts'
      def rm(uid)
        count = 0

        scope = scope_from_uid(uid)

        puts colorize("Deleting posts", :yellow, :bright)
        Post.transaction do
          scope.find_each do |post|
            puts colorize("Deleting #{post.uid}", :red)
            post.deleted = true
            post.save!
            count += 1
          end
        end
        puts if count > 0
        puts('%8d posts deleted.' % count)
      end

      private

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
