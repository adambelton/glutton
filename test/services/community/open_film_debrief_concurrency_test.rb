require "test_helper"
require "timeout"

module Community
  class OpenFilmDebriefConcurrencyTest < ActiveSupport::TestCase
    self.use_transactional_tests = false

    setup do
      @film = Registry::Film.create!(title: "Concurrent debrief", tmdb_metadata: { details: {} })
      password = "a long test password"
      @members = %w[debrief_opener debrief_contender].map do |name|
        Identity::UserRegistered.create!(email_address: "#{name}@example.test", password:, password_confirmation: password,
          email_confirmed_at: Time.current, superuser: true, community_username: name, community_avatar_preset: "moth",
          community_code_of_conduct_version: CodeOfConduct.current.version, community_code_of_conduct_accepted_at: Time.current)
      end
      @members.each { |member| Library::LibraryFilm.new(user: member, film: @film).add_to_watched! }
    end

    teardown do
      @contender&.kill if @contender&.alive?
      @contender&.join
      PostFilmDebrief.where(film: @film).delete_all
      @members.each(&:destroy!)
      @film.destroy!
    end

    test "two members opening the same film resolve to one canonical debrief" do
      backend_pid = Queue.new
      original = PostFilmDebrief.transaction do
        debrief = OpenFilmDebrief.call(member_id: @members.first.id, film_id: @film.id)
        @contender = Thread.new do
          PostFilmDebrief.with_connection do |connection|
            backend_pid << connection.select_value("SELECT pg_backend_pid()")
            OpenFilmDebrief.call(member_id: @members.last.id, film_id: @film.id)
          end
        end

        pid = Timeout.timeout(5) { backend_pid.pop }
        PostFilmDebrief.with_connection do |connection|
          Timeout.timeout(5) do
            until connection.uncached { connection.select_value("SELECT cardinality(pg_blocking_pids(#{Integer(pid)}))") }.positive?
              sleep 0.01
            end
          end
        end
        debrief
      end

      repeated = Timeout.timeout(5) { @contender.value }
      assert_equal original.id, repeated.id
      assert_equal original.id, PostFilmDebrief.where(film: @film).sole.id
    end
  end
end
