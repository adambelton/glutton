require "test_helper"

class CommunityNotificationsTest < ActionDispatch::IntegrationTest
  include ActiveJob::TestHelper

  ALL_RATINGS = %w[brilliant pretty_good not_for_me garbage unrated].freeze

  setup do
    @author = member("notification_author")
    @reader = member("notification_reader")
    @third = member("notification_third")
    @film = Registry::Film.create!(title: "The Quiet Hour", tmdb_metadata: { details: { genres: [ { name: "Horror" } ] } })
    [ @author, @reader, @third ].each { |user| Library::LibraryFilm.new(user:, film: @film).add_to_watched! }
    @debrief = Community::FilmDebriefs::OpenFilmDebrief.call(community_user: @author.community_user, film_id: @film.id)
  end

  test "account and post preferences notify once for future top-level debrief comments" do
    settings(@author, ratings: ALL_RATINGS)
    settings(@reader, ratings: [ "brilliant" ])
    settings(@third, ratings: ALL_RATINGS)
    rating = Ratings::RatingFilm.create!(user: @reader, film: @film).submit_rating!(value: "brilliant")

    comment = publish(@author, "A brilliant debrief worth following.")
    Community::DeliverCommentNotificationJob.perform_now(comment.content.id)
    assert_equal [ @reader.id, @third.id ].sort,
      Community::Notification.where(comment_content: comment.content).pluck(:recipient_id).sort

    revised = rating.rating_film.revise_rating!(previous_rating_id: rating.id, value: "garbage")
    comment = publish(@author, "The Brilliant filter follows the current rating.")
    assert_equal [ @third.id ], Community::Notification.where(comment_content: comment.content).pluck(:recipient_id)

    rating.rating_film.revise_rating!(previous_rating_id: revised.id, value: "brilliant")
    follow_post(@reader, following: false)
    comment = publish(@author, "The mute overrides the matching rating.")
    assert_equal [ @third.id ], Community::Notification.where(comment_content: comment.content).pluck(:recipient_id)

    settings(@reader)
    follow_post(@reader, following: true)
    comment = publish(@author, "An explicit follow applies with the default off.")
    assert Community::Notification.exists?(comment_content: comment.content, recipient: @reader)
    follow_post(@reader, following: false)
    refute Community::PostNotificationPreference.exists?(user: @reader, post: @debrief)
    comment = publish(@author, "The default is off again.")
    refute Community::Notification.exists?(comment_content: comment.content, recipient: @reader)
  end

  test "the direct reply targets the immediate author and keeps separate settings" do
    settings(@third, ratings: ALL_RATINGS)
    root = publish(@reader, "Here is a new conversation.")
    settings(@reader, ratings: [ "unrated" ])
    follow_post(@reader, following: false)
    reply = publish(@author, "This is a direct reply.", parent: root)
    nested = publish(@third, "This is a reply to the reply.", parent: reply)
    assert_equal [ @reader.id ], Community::Notification.where(comment_content: reply.content).pluck(:recipient_id)
    assert_equal [ @author.id ], Community::Notification.where(comment_content: nested.content).pluck(:recipient_id)

    pending_reply = publish(@third, "A reply queued before the Film Debrief preferences changed.", parent: root, deliver: false)
    settings(@reader, ratings: [ "unrated" ])
    Community::DeliverCommentNotificationJob.perform_now(pending_reply.content.id)
    assert Community::Notification.exists?(recipient: @reader, comment_content: pending_reply.content)

    settings(@reader, ratings: [ "unrated" ], replies: "0")
    muted_reply = publish(@third, "A reply after turning alerts off.", parent: root)
    refute Community::Notification.exists?(comment_content: muted_reply.content)

    queued_reply = publish(@third, "A reply queued while alerts were off.", parent: root, deliver: false)
    settings(@reader, ratings: [ "unrated" ], replies: "1")
    Community::DeliverCommentNotificationJob.perform_now(queued_reply.content.id)
    assert Community::Notification.exists?(recipient: @reader, comment_content: queued_reply.content)

    sign_in(@author)
    assert_no_enqueued_jobs(only: Community::DeliverCommentNotificationJob) do
      post community_post_comments_path(@debrief), params: { body: "" }
      assert_response :unprocessable_content
    end
  end

  test "Unrated matches the absence of a rating independently of the four rated choices" do
    settings(@reader, ratings: [ "unrated" ])
    comment = publish(@author, "A new comment on an unrated Watched film.")
    assert Community::Notification.exists?(recipient: @reader, comment_content: comment.content)

    pending = publish(@author, "Published before a rating was added.", deliver: false)
    Ratings::RatingFilm.create!(user: @reader, film: @film).submit_rating!(value: "brilliant")
    Community::DeliverCommentNotificationJob.perform_now(pending.content.id)
    refute Community::Notification.exists?(recipient: @reader, comment_content: pending.content)

    comment = publish(@author, "The film is now Brilliant rather than Unrated.")
    refute Community::Notification.exists?(recipient: @reader, comment_content: comment.content)
  end

  test "a curation reply uses the same inbox and removing its content clears its notification" do
    curation = Community::Curations::PublishCuration.call(community_user: @reader.community_user, title: "Quiet houses",
      description: "Films about unsettling houses.", reference_film_ids: [ @film.id ], reference_comments: { @film.id => "An example." })
    root = curation.comments.sole
    reply = publish(@author, "A direct reply in a curation.", parent: root, post_record: curation)
    item = Community::Notification.find_by!(comment_content: reply.content, recipient: @reader)
    sign_in(@reader)
    patch community_debrief_notification_path(curation), params: { following: "1" }
    assert_response :not_found
    refute Community::PostNotificationPreference.exists?(user: @reader, post: curation)
    get notifications_path
    assert_response :ok
    assert_select "button", text: /New reply to your comment on Quiet houses/

    nested_reply = publish(@third, "This reply survives removal of its parent content.", parent: reply, post_record: curation)
    sign_in(@author)
    delete community_post_comment_path(curation, reply)
    assert_response :see_other
    refute Community::Notification.exists?(item.id)
    assert_equal reply.id, nested_reply.reload.parent_id
    assert_nil reply.reload.content
  end

  test "the inbox and its unread indicator hide blocked and inaccessible comments" do
    follow_post(@reader, following: true)
    comment = publish(@author, "Only visible with access.")
    item = Community::Notification.find_by!(comment_content: comment.content, recipient: @reader)
    sign_in(@third)
    post open_notification_path(item)
    assert_response :not_found

    sign_in(@reader)
    get notifications_path
    assert_select "a[aria-label='Notifications (unread)']"
    assert_select "button", text: /New comment on The Quiet Hour/

    [ [ @reader, @author ], [ @author, @reader ] ].each do |blocker, blocked|
      blocker.community_user.block_member!(member: blocked.community_user)
      assert_hidden(item)
      blocker.community_user.unblock_member!(member: blocked.community_user)
    end

    post open_notification_path(item)
    assert_redirected_to community_post_path(@debrief, reply: comment.id, anchor: "comment-#{comment.id}")
    assert item.reload.read_at.present?

    unread_comment = publish(@author, "Another update before losing access.")
    unread_item = Community::Notification.find_by!(comment_content: unread_comment.content, recipient: @reader)
    Library::LibraryFilm.find_by!(user: @reader, film: @film).move_to_watchlist!
    sign_in(@reader)
    assert_hidden(unread_item)
  end

  test "a queued notification respects a new follow and uses current Watched access" do
    comment = publish(@author, "Posted before the reader opted in.", deliver: false)
    follow_post(@reader, following: true)
    Community::DeliverCommentNotificationJob.perform_now(comment.content.id)
    assert Community::Notification.exists?(recipient: @reader, comment_content: comment.content)

    comment = publish(@author, "The reader later loses access.", deliver: false)
    entry = Library::LibraryFilm.find_by!(user: @reader, film: @film)
    entry.move_to_watchlist!
    Community::DeliverCommentNotificationJob.perform_now(comment.content.id)
    refute Community::Notification.exists?(recipient: @reader, comment_content: comment.content)

    comment = publish(@author, "The reader gets Watched access before the job runs.", deliver: false)
    entry.move_to_watched!
    Community::DeliverCommentNotificationJob.perform_now(comment.content.id)
    assert Community::Notification.exists?(recipient: @reader, comment_content: comment.content)
  end

  test "resetting to the default deletes a mute and queued notifications use the current rating choices" do
    settings(@reader, ratings: [ "unrated" ])
    follow_post(@reader, following: false)
    queued = publish(@author, "A comment while the film was muted.", deliver: false)
    follow_post(@reader, following: true)
    refute Community::PostNotificationPreference.exists?(user: @reader, post: @debrief)
    settings(@reader, ratings: [ "brilliant" ])
    Ratings::RatingFilm.create!(user: @reader, film: @film).submit_rating!(value: "brilliant")

    Community::DeliverCommentNotificationJob.perform_now(queued.content.id)
    assert Community::Notification.exists?(recipient: @reader, comment_content: queued.content)

    queued = publish(@author, "A comment queued before the reader mutes again.", deliver: false)
    follow_post(@reader, following: false)
    Community::DeliverCommentNotificationJob.perform_now(queued.content.id)
    refute Community::Notification.exists?(recipient: @reader, comment_content: queued.content)
  end

  test "private settings are available to readers without a Community profile and close with the account" do
    password = "a long test password"
    reader = Identity::UserRegistered.create!(email_address: "private-reader@example.test", password:,
      password_confirmation: password, email_confirmed_at: Time.current)
    Library::LibraryFilm.new(user: reader, film: @film).add_to_watched!
    settings(reader, ratings: ALL_RATINGS, replies: "0")
    get account_community_path
    assert_select "#notification-settings", text: "Notifications"
    assert_nil reader.community_user
    comment = publish(@author, "Accessible without a public profile.")
    assert Community::Notification.exists?(comment_content: comment.content, recipient: reader)

    reader.destroy_with_activity!
    refute Community::FilmDebriefNotificationPreference.exists?(user_id: reader.id)
    refute Community::DiscussionNotificationPreference.exists?(user_id: reader.id)
    refute Community::Notification.exists?(recipient_id: reader.id)
  end

  test "a source rollback also removes the durable notification job" do
    job = Community::DeliverCommentNotificationJob
    adapter = job.queue_adapter
    job.queue_adapter = :good_job
    jobs = GoodJob::Job.where(job_class: job.name)
    assert_no_difference [ -> { jobs.count }, -> { Community::CommentContent.count } ] do
      Community::CommentContent.transaction(requires_new: true) do
        assert_difference -> { jobs.count }, 1 do
          publish(@author, "This comment is rolled back.", deliver: false)
        end
        raise ActiveRecord::Rollback
      end
    end
  ensure
    job.queue_adapter = adapter
  end

  private

  def member(name)
    password = "a long test password"
    create_community_account(email_address: "#{name}@example.test", password:, password_confirmation: password,
      email_confirmed_at: Time.current, community_username: name, community_avatar_preset: "moth",
      community_code_of_conduct_version: Community::CodeOfConduct.current.version, community_code_of_conduct_accepted_at: Time.current)
  end

  def sign_in(user)
    authentication = Identity::Session.create!(user:)
    jar = ActionDispatch::Request.new(Rails.application.env_config.dup).cookie_jar
    jar.signed[:session_id] = { value: { id: authentication.id, user_id: user.id } }
    cookies[:session_id] = jar[:session_id]
  end

  def publish(user, body, parent: nil, post_record: @debrief, deliver: true)
    sign_in(user)
    path = parent.present? ? reply_community_post_comment_path(post_record, parent) : community_post_comments_path(post_record)
    if deliver
      perform_enqueued_jobs(only: Community::DeliverCommentNotificationJob) { post path, params: { body: } }
    else
      post path, params: { body: }
    end
    assert_response :see_other
    Community::CommentContent.find_by!(community_user: user.community_user, body:).comment
  end

  def settings(user, ratings: [], replies: "1")
    sign_in(user)
    patch account_community_notifications_path, params: { rating_values: ratings.presence, direct_replies: replies }.compact
    assert_response :see_other
  end

  def follow_post(user, following:)
    sign_in(user)
    patch community_debrief_notification_path(@debrief), params: { following: following ? "1" : "0" }
    assert_response :see_other
  end

  def assert_hidden(item)
    get notifications_path
    assert_response :ok
    assert_select "a[aria-label='Notifications (unread)']", count: 0
    assert_select "form[action=?]", open_notification_path(item), count: 0
    post open_notification_path(item)
    assert_response :not_found
  end
end
