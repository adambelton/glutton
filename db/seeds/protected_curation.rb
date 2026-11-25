module Seeds
  class ProtectedCuration
    AUTHOR_EMAIL = "hello@adambelton.com"
    TITLE = "[Local test] Atmospheric horror worth a second look"
    PASSWORD = "local-curation-preview"
    READERS = {
      "curation-reader-one@example.test" => [ "curation_reader_one", "moth" ],
      "curation-reader-two@example.test" => [ "curation_reader_two", "raven" ]
    }.freeze

    def self.call
      new.call
    end

    def call
      Community::PostCommunityCuration.transaction do
        author = Identity::UserRegistered.lock.find_by!(email_address: AUTHOR_EMAIL)
        unless Community::PostingAccess.allowed?(user: author)
          raise "Complete Community setup for #{AUTHOR_EMAIL} before running the seed."
        end

        readers = READERS.map { |email, (username, avatar)| prepare_reader(email:, username:, avatar:, author:) }
        curation = Community::PostCommunityCuration.find_by(title: TITLE, author_id: [ author.id, nil ])
        curation ||= publish_curation(author:, readers:)
        raise "The local curation did not reach the protection threshold." unless curation.reload.protected?

        curation
      end
    end

    private

    def prepare_reader(email:, username:, avatar:, author:)
      reader = Identity::UserRegistered.find_or_create_by!(email_address: email) do |member|
        member.password = PASSWORD
        member.password_confirmation = PASSWORD
        member.email_confirmed_at = Time.current
      end
      reader.grant_superuser!(actor: author) unless reader.superuser?
      version = Community::CodeOfConduct.current.version
      unless reader.accepted_community_code_of_conduct?(version:)
        Community::AcceptCodeOfConduct.call(user_id: reader.id, displayed_version: version, accepted: true)
      end
      profile = Community::ManageMemberProfile.new(user_id: reader.id)
      profile.change_username(community_username: username) unless reader.community_username.present?
      profile.choose_avatar(preset: avatar) unless reader.community_avatar_preset.present?
      reader.reload
    end

    def publish_curation(author:, readers:)
      first_film, second_film = Community::EligibleCurationFilms.new(member: author).choices.first(2)
      raise "Mark two horror films as Watched for #{AUTHOR_EMAIL} first." unless second_film.present?

      curation = Community::PublishCuration.call(author_id: author.id, title: TITLE,
        prompt: "Which horror films build dread through atmosphere, setting, and patient pacing?",
        reference_film_ids: [ first_film.id, second_film.id ],
        reference_comments: {
          first_film.id => "The confined setting makes every small change feel important.",
          second_film.id => "I like the way the atmosphere builds before the film shows much."
        })
      raise ActiveRecord::RecordInvalid, curation if curation.errors.any?

      first_reader, second_reader = readers
      endorse(curation:, reader: first_reader, film: first_film, body: "The setting creates a lot of tension on its own.")
      endorse(curation:, reader: second_reader, film: second_film, body: "The slower moments give the tension room to build.")

      root = curation.film_endorsements.find_by!(user: author, film: first_film).opening_comment
      first_reply = reply(curation:, parent: root, member: first_reader, body: "I noticed how much the sound design contributes.")
      reply(curation:, parent: first_reply, member: second_reader, body: "The quiet scenes stood out to me for the same reason.")
      reply(curation:, parent: root, member: second_reader, body: "The pacing is what makes it a good match for this list.")
      curation
    end

    def endorse(curation:, reader:, film:, body:)
      unless Library::LibraryFilm.watched.exists?(user: reader, film:)
        Library::CollectionManagement::MarkWatched.call(user_id: reader.id, film_id: film.id)
      end
      draft = Community::EditCurationEndorsements.load_for_edit(curation_id: curation.id, member: reader)
      result = Community::EditCurationEndorsements.call(curation_id: curation.id, member_id: reader.id,
        film_ids: [ film.id ], comments: { film.id => body }, snapshot: draft.fetch(:snapshot))
      saved = result.fetch(:curation)
      raise ActiveRecord::RecordInvalid, saved if saved.errors.any?
    end

    def reply(curation:, parent:, member:, body:)
      content = Community::PublishCurationReply.call(curation_id: curation.id, comment_id: parent.id, member_id: member.id, body:)
        .fetch(:reply)
      raise ActiveRecord::RecordInvalid, content unless content.persisted?

      content.comment
    end
  end
end
