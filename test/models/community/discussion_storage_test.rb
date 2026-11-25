require "test_helper"

module Community
  class DiscussionStorageTest < ActiveSupport::TestCase
    test "a debrief root must reference its own canonical film and a curation root still requires an endorsement" do
      film = Registry::Film.create!(title: "Debrief film", tmdb_metadata: { details: {} })
      another_film = Registry::Film.create!(title: "Another film", tmdb_metadata: { details: {} })
      debrief = PostFilmDebrief.open_for!(film:)
      password = "a long test password"
      author = Identity::UserRegistered.create!(email_address: "discussion-storage@example.test", password:,
        password_confirmation: password, email_confirmed_at: Time.current)
      curation = PostCommunityCuration.create!(title: "A curation", prompt: "Curation text.", author:)

      assert_raises ActiveRecord::InvalidForeignKey do
        Comment.transaction(requires_new: true) do
          Comment.insert_all!([ { post_id: debrief.id, debrief_film_id: another_film.id } ])
        end
      end

      assert_raises ActiveRecord::InvalidForeignKey do
        Comment.transaction(requires_new: true) do
          Comment.insert_all!([ { post_id: curation.id, debrief_film_id: film.id } ])
        end
      end

      assert_raises ActiveRecord::StatementInvalid do
        Comment.transaction(requires_new: true) do
          Comment.insert_all!([ { post_id: curation.id } ])
        end
      end
    end
  end
end
