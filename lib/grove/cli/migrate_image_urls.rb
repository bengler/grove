# {"percent":0,"status":"received"}
# {"percent":0,"status":"transferring"}
# {"percent":90,"status":"transferring"}
# {"percent":100,"status":"completed","metadata":{"uid":"image:apdm.oa.lifeloop.birthday$20160912121550-433-ipu7","baseurl":"https://s3-eu-west-1.amazonaws.com/staging.o5.no/apdm/oa/lifeloop/birthday/20160912121550-433-ipu7","original":"https://s3-eu-west-1.amazonaws.com/staging.o5.no/apdm/oa/lifeloop/birthday/20160912121550-433-ipu7/original.jpg","fullsize":"https://s3-eu-west-1.amazonaws.com/staging.o5.no/apdm/oa/lifeloop/birthday/20160912121550-433-ipu7/513.jpg","aspect_ratio":0.433,"secure_access":true,"versions":[{"width":100,"square":false,"url":"https://s3-eu-west-1.amazonaws.com/staging.o5.no/apdm/oa/lifeloop/birthday/20160912121550-433-ipu7/100.jpg"},{"width":100,"square":true,"url":"https://s3-eu-west-1.amazonaws.com/staging.o5.no/apdm/oa/lifeloop/birthday/20160912121550-433-ipu7/100sq.jpg"},{"width":300,"square":false,"url":"https://s3-eu-west-1.amazonaws.com/staging.o5.no/apdm/oa/lifeloop/birthday/20160912121550-433-ipu7/300.jpg"},{"width":500,"square":true,"url":"https://s3-eu-west-1.amazonaws.com/staging.o5.no/apdm/oa/lifeloop/birthday/20160912121550-433-ipu7/500sq.jpg"},{"width":513,"square":false,"url":"https://s3-eu-west-1.amazonaws.com/staging.o5.no/apdm/oa/lifeloop/birthday/20160912121550-433-ipu7/513.jpg"}]}}
#
#
# post.greeting
#   document.image = {}
#
# post.stream_image # verify document.source == 'tiramisu'
#   document = {}
#
# post.image
#   document = {}
#
# post.letter # verify document.author_details.author_image.type != 'reference'
#   document.author_details.author_image = {}
#
# post.story # verify document.illustration_images[x].type != 'reference'
#   document.illustration_images = [{}]
#
# post.event:apdm.arrangutang.*
#   document.image_thumb = ''
#   document.image_full = ''
#
# post.artist
#   document.image_url = ''
#   document.image_thumbnail = ''
#   document.image_square = ''
#
#
# post.track
#   document.audio_file_url = ''
#
#
#
# https://as3-eu-west-1.amazonaws.com/apps.o5.no/apdm/bandwagon/inner/ringblad/4445/20120603203356-khuv-mp3/tobasko-animalistic-original-mix_44100_128000.mp3
#
#
#
# [{"post.artist"=>2200}, {"post.event"=>64315}, {"post.greeting"=>628356}, {"post.hermes_message"=>100364}, {"post.image"=>12217}, {"post.letter"=>388}, {"post.story"=>158}, {"post.stream_image"=>35598}, {"post.tip"=>8012}, {"post.track"=>4635}]
#
# Post.where(realm: 'apdm').where('document LIKE ?', '%http://apps.o5.no.s3%').group('klass').count.map{|s| {s[0] => s[1]}}.sort_by { |k| k.keys[0] }
#
#
#
#
# klasses = ['post.greeting', 'post.stream_image', 'post.image', 'post.event', 'post.artist', 'post.letter', 'post.story', 'post.track']
#
# klasses.each do |klass|
#   posts = Post.where(realm: 'apdm', klass: klass).where('document LIKE ?', '%http://apps.o5.no.s3%')
# end


require 'pp'
require_relative './colorization'
require_relative './utility'

module Grove
  module CLI

    class MigrateImageUrls

      include Colorization
      include Utility

      class NonS3Source < StandardError; end
      class MalformedImage < StandardError; end

      KLASSES = ['post.greeting', 'post.stream_image', 'post.image', 'post.event', 'post.artist', 'post.letter', 'post.story', 'post.track']
      #KLASSES = ['post.letter']

      def self.build(program)
        program.command :migrate_image_urls do |c|
          c.syntax "migrate_image_urls [UID]"
          c.description "Migrate posts including S3 urls to use the https path"
          c.action do |args, options|
            MigrateImageUrls.new.process(args, options)
          end
        end
      end

      def process(args = [], options = {})
        if args.first == 'all'
          limit = (args[1] || 100).to_i
          migrate_all!(limit)
        else
          count = 0
          uid = args.first
          puts colorize("Migrating", :yellow, :bright)
          scope = scope_from_uid(uid)
          Post.transaction do
            scope.find_each do |post|
              puts colorize("Migrating #{post.uid}", :red)
              migrate!(post)
              count += 1
            end
          end
          puts if count > 0
          puts('%8d posts migrated.' % count)
        end
      end


      def migrate_all!(limit, batch_size = 512)
        failures = {}
        KLASSES.each do |klass|
          ids = Post
            .where('document NOT LIKE ?', '%secure_access%')
            .where('document LIKE ?', '%http://apps.o5.no.s3%')
            .where(realm: 'apdm')
            .where(klass: klass)
            .order('created_at desc')
            .limit(limit)
            .pluck(:id)

          num = ids.count
          count = 0
          previous_message = ''
          puts colorize("\n#{klass} [#{num}]", :yellow, :bright)
          ids.each_slice(batch_size) do |chunk|
            Post.find(chunk).each do |post|
              begin
                migrate!(post)
              rescue MalformedImage, NonS3Source => e
                failures[post.uid] = "#{e.class}"
                next
              end
              count += 1
              message = "#{format("%.2f", (count * 100.0 / num))}%"
              if message != previous_message
                print "\b" * previous_message.length
                print colorize(message, :yellow, :bright)
              end
              previous_message = message
            end
          end
        end
        puts ''
        puts colorize("Errors #{pp(failures)}", :red, :bright)
      end


      def migrate!(post)
        doc = post.document

        case post.klass

        when 'post.greeting'
          doc['image'] = fix_image(doc['image'])

        when 'post.stream_image'
          doc = fix_image(doc)

        when 'post.image'
          doc = fix_image(doc)

        when 'post.letter'
          author_image = doc['author_details'] && doc['author_details']['author_image']
          if author_image
            author_image = fix_image(author_image)
            doc['author_details']['author_image'] = author_image
          end

        when 'post.story'
          images = doc['illustration_images'].compact
          if images
            images = images.map do |illustration_image|
              return illustration_image if illustration_image['type'] == 'reference'
              fix_image(illustration_image)
            end
            doc['illustration_images'] = images
          end

        when 'post.event'
          if (doc['image_thumb'] && doc['image_thumb'].is_a?(Hash))
            # hack to fix borked image_thumb
            doc['image_thumb'] = doc['image_thumb']['url']
          else
            doc['image_thumb'] = fix_url(doc['image_thumb'])
          end
          doc['image_full'] = fix_url(doc['image_full'])

        when 'post.artist'
          doc['image_url'] = fix_url(doc['image_url'])
          doc['image_thumbnail'] = fix_url(doc['image_thumbnail'])
          doc['image_square'] = fix_url(doc['image_square'])

        when 'post.track'
          doc['audio_file_url'] = fix_url(doc['audio_file_url'])

        else
          raise "WTF? Klass for post: #{post.uid}"
        end

        # We're all good. Save the post.
        doc['secure_access'] = true
        post.document = doc
        post.save
      end


      def fix_image(image)
        return nil unless image
        return image if image['source'] == 'instagram'

        raise MalformedImage unless image['original']

        ['baseurl', 'fullsize', 'original'].each do |url_kind|
          url = image[url_kind]
          image[url_kind] = fix_url(url) if url
        end
        image['versions'] = (image['versions'] && image['versions']).map do |version|
          version['url'] = fix_url(version['url'])
          version
        end
        image
      end


      def fix_url(http_url)
        return nil unless http_url
        raise NonS3Source unless http_url.start_with? 'http://apps.o5.no.s3.amazonaws.com/'

        path = http_url.split('s3.amazonaws.com/').last
        "https://s3-eu-west-1.amazonaws.com/apps.o5.no/#{path}"
      end

    end

  end
end
