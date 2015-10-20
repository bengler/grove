
# This is a one off. Written in order to reboot Velkomat data and start afresh.

require_relative './colorization'
require_relative './utility'

module Grove
  module CLI

    class IssueNuker

      include Colorization
      include Utility

      def self.build(program)
        program.command :dna_issue_nuker do |c|
          c.syntax "touch UID ..."
          c.description "Nuke DNA issues"
          c.action do |args, options|
            IssueNuker.new.nuke_all! 'post.issue'
            IssueNuker.new.nuke_all! 'post.issue_update'
          end
        end
      end


      def nuke_all!(klass, batch_size = 512)
        options = {
          realm: 'dna',
          klass: klass,
          deleted: false
        }
        ids = Post.unscoped.where(options).order('created_at DESC').pluck(:id)
        num = ids.count
        puts colorize("Total #{klass} to handle: #{num}", :red, :bright)

        count = 0
        percent = 0
        previous_message = 0
        ids.each_slice(batch_size) do |chunk|
          Post.find(chunk).each do |post|
            post.deleted = true
            post.save!
            count += 1
            message = "#{format("%.1f", (count * 100.0 / num))}%"
            if message != previous_message
              print "\b" * message.length
              print colorize(message, :yellow, :bright)
            end
            previous_message = message
          end
        end;nil
        puts colorize(" ...all done!", :green, :bright)
      end

    end

  end
end
