
# This is a one off. Written in order to recover lost post.person data

require_relative './colorization'
require_relative './utility'

module Grove
  module CLI

    class DnaPersonDataRecover

      include Colorization
      include Utility

      def self.build(program)
        program.command :dna_person_data_recover do |c|
          c.syntax "recover"
          c.description "Recover person data"
          c.action do |args, options|
            DnaPersonDataRecover.new.handle_all!
          end
        end
      end


      def handle_all!
        done = {}
        # find all deleted posts in time window
        ids = Post.unscoped.where(klass: 'post.person', realm: 'dna', deleted: true).where('updated_at > ?', Time.new(2016, 2, 18)).order('created_at asc').pluck(:id)

        num = ids.count
        puts colorize("Total persons to handle: #{num}", :green, :bright)

        ids.each_slice(512) do |chunk|
          Post.unscoped.find(chunk).each do |deleted_person|
            handle! deleted_person
            done[deleted_person.id] = true
          end
        end
        puts colorize("All done! #{num}/#{done.count}", :green, :bright)
      end


      def handle!(deleted_person)
        deleted_doc = deleted_person.document
        unless deleted_doc['external_id']
          puts colorize("No archived external_id for #{deleted_person.id}, bailing", :red, :bright)
          return
        end

        # find the current, undeleted post
        current_person = Post.find_by_external_id(deleted_doc['external_id'])
        unless current_person
          puts colorize("No existing person matching #{deleted_doc['external_id']}, bailing", :red, :bright)
          return
        end

        doc = current_person.document

        # Bail unless names are equal
        unless doc['name'] == deleted_doc['name']
          puts colorize("Deleted and current (#{deleted_person.id} / #{current_person.id}) have mismatching names (#{deleted_doc['name']} / #{doc['name']}), bailing", :red, :bright)
          return
        end

        # Let's go
        puts colorize("#{deleted_doc['name']} (#{current_person.external_id})", :green, :dim)

        # Put back old field values on current_person
        ['image', 'facebook', 'twitter', 'bio'].each do |field|
          if deleted_doc[field] && !doc[field]
            next if deleted_doc[field].class == String && deleted_doc[field].strip.empty?
            doc[field] = deleted_doc[field]
            puts colorize("  #{field}: #{deleted_doc[field]}", :green, :bright)
          end
        end
        # Write back updated document
        current_person.document = doc


        # Sensitive
        sens = current_person.sensitive || {}
        deleted_sens = deleted_person.sensitive || {}

        ['email', 'phone'].each do |field|
          if deleted_sens[field] && !sens[field]
            sens[field] = deleted_sens[field]
            puts colorize("  #{field}: #{deleted_sens[field]}", :green, :bright)
          end
        end
        # Write back the sensitive field
        current_person.sensitive = sens

        # Save current_person
        current_person.save!
      end

    end

  end
end
