require "test_helper"
require "timeout"

class CommunityMemberBlockConcurrencyTest < ActiveSupport::TestCase
  self.use_transactional_tests = false

  test "a reply waiting for a block to commit rechecks the parent before publishing" do
    author = member("RaceAuthor")
    reader = member("RaceReader")
    film = Registry::Film.create!(title: "A contested reply", tmdb_metadata: { details: { genres: [ { name: "Horror" } ] } })
    Library::LibraryFilm.new(user: author, film:).add_to_watched!
    curation = Community::Curations::PublishCuration.call(community_user: author.community_user, title: "Folk Horror",
      description: "Horror in small villages.", reference_film_ids: [ film.id ], reference_comments: { film.id => "An example." })
    parent = curation.comments.sole
    reader_profile = reader.community_user
    ready = Queue.new

    Identity::UserRegistered.transaction do
      Community::Membership::ManageMemberBlocks.block(user_id: author.id, member_id: reader.id)
      @reply = Thread.new do
        ActiveRecord::Base.connection_pool.with_connection do |connection|
          ready << connection.select_value("SELECT pg_backend_pid()")
          Community::Discussions::PublishCurationReply.call(curation_id: curation.id, comment_id: parent.id,
            community_user: reader_profile, body: "Waiting reply")
        rescue ActiveRecord::RecordNotFound => error
          error
        end
      end
      pid = Integer(Timeout.timeout(5) { ready.pop })
      connection = ActiveRecord::Base.connection
      Timeout.timeout(5) do
        until connection.uncached { connection.select_value("SELECT cardinality(pg_blocking_pids(#{pid}))") }.positive?
          sleep 0.01
        end
      end
    end

    assert_instance_of ActiveRecord::RecordNotFound, Timeout.timeout(5) { @reply.value }
    assert_not parent.post.comments.exists?(parent_id: parent.id)
  ensure
    @reply&.kill if @reply&.alive?
    @reply&.join
    reader&.destroy_with_activity!
    author&.destroy_with_activity!
    film&.destroy!
  end

  private

  def member(name)
    password = "a long test password"
    create_community_account(email_address: "#{name.downcase}@example.test", password:, password_confirmation: password,
      email_confirmed_at: Time.current, community_code_of_conduct_version: Community::CodeOfConduct.current.version,
      community_code_of_conduct_accepted_at: Time.current, community_username: name, community_avatar_preset: "moth")
  end
end
