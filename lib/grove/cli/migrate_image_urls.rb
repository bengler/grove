# {"percent":0,"status":"received"}
# {"percent":0,"status":"transferring"}
# {"percent":90,"status":"transferring"}
# {"percent":100,"status":"completed","metadata":{"uid":"image:apdm.oa.lifeloop.birthday$20160912121550-433-ipu7","baseurl":"https://s3-eu-west-1.amazonaws.com/staging.o5.no/apdm/oa/lifeloop/birthday/20160912121550-433-ipu7","original":"https://s3-eu-west-1.amazonaws.com/staging.o5.no/apdm/oa/lifeloop/birthday/20160912121550-433-ipu7/original.jpg","fullsize":"https://s3-eu-west-1.amazonaws.com/staging.o5.no/apdm/oa/lifeloop/birthday/20160912121550-433-ipu7/513.jpg","aspect_ratio":0.433,"secure_access":true,"versions":[{"width":100,"square":false,"url":"https://s3-eu-west-1.amazonaws.com/staging.o5.no/apdm/oa/lifeloop/birthday/20160912121550-433-ipu7/100.jpg"},{"width":100,"square":true,"url":"https://s3-eu-west-1.amazonaws.com/staging.o5.no/apdm/oa/lifeloop/birthday/20160912121550-433-ipu7/100sq.jpg"},{"width":300,"square":false,"url":"https://s3-eu-west-1.amazonaws.com/staging.o5.no/apdm/oa/lifeloop/birthday/20160912121550-433-ipu7/300.jpg"},{"width":500,"square":true,"url":"https://s3-eu-west-1.amazonaws.com/staging.o5.no/apdm/oa/lifeloop/birthday/20160912121550-433-ipu7/500sq.jpg"},{"width":513,"square":false,"url":"https://s3-eu-west-1.amazonaws.com/staging.o5.no/apdm/oa/lifeloop/birthday/20160912121550-433-ipu7/513.jpg"}]}}
#
#
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
# post.event:apdm.arrangutang.*
#   document.image_thumb = ''
#   document.image_full = ''
#
# post.artist
#   document.image_url = ''
#   document.image_thumbnail = ''
#   document.image_square = ''
#
# post.letter # verify document.author_details.author_image.type != 'reference'
#   document.author_details.author_image = {}
#
# post.story # verify document.illustration_images[x].type != 'reference'
#   document.illustration_images = [{}]
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




require_relative './colorization'
require_relative './utility'

module Grove
  module CLI

    class MigrateImageUrls

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
            message = "#{format("%.3f", (count * 100.0 / num))}%"
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
