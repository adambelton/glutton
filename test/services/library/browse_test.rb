require "test_helper"

class Library::BrowseTest < ActiveSupport::TestCase
  test "missing and expired owners cannot browse" do
    assert_raises(Library::IdentityUnavailable) do
      Library::Browse.call(user_id: -1, view: Library::Browse::Views::WATCHLIST, page: 1)
    end
    user = UserGuest.create!
    travel UserGuest::EXPIRY_DURATION + 1.second do
      assert_raises(Library::IdentityUnavailable) do
        Library::Browse.call(user_id: user.id, view: Library::Browse::Views::WATCHLIST, page: 1)
      end
    end
  end

  test "query count stays bounded as the watched list grows and film data is preloaded" do
    user = UserGuest.create!
    create_entry = -> { LibraryFilmWatched.create!(user:, film: Film.create!(title: "Film")) }
    create_entry.call
    count_queries = lambda do
      queries = []
      subscriber = ->(_name, _start, _finish, _id, payload) { queries << payload unless payload[:name] == "SCHEMA" || payload[:cached] }
      ActiveSupport::Notifications.subscribed(subscriber, "sql.active_record") do
        page = Library::Browse.call(user_id: user.id, view: Library::Browse::Views::WATCHED, page: 1)
        page.entries.each { |row| row.film.title }
      end
      queries.size
    end
    single_count = count_queries.call
    29.times { create_entry.call }
    assert_equal single_count, count_queries.call
    page = Library::Browse.call(user_id: user.id, view: Library::Browse::Views::WATCHED, page: 1)
    assert_equal 25, page.entries.size
    assert page.next_page
  end
end
