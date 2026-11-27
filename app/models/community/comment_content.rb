module Community
  class CommentContent < ApplicationRecord
    include Reportable

    BODY_LIMIT = 4_000

    belongs_to :comment, inverse_of: :content
    belongs_to :community_user, class_name: "Community::CommunityUser"

    normalizes :body, with: ->(text) { text.strip }

    validates :body, presence: true
    validates :body, length: { maximum: BODY_LIMIT }, if: :will_save_change_to_body?

    def self.body_too_long?(body)
      normalize_value_for(:body, body).to_s.length > BODY_LIMIT
    end

    def reportable_attributes
      { "body" => body }
    end

    def reported_member
      community_user.user
    end

    def report_reasons
      comment.post.report_reasons
    end

    def edit_body(body:)
      self.body = body
      self.edited_at = Time.current if will_save_change_to_body?
      save
      self
    end

    def lock_for_report_deletion!
      Post.lock.find(Comment.find(comment_id).post_id)
      super
    end

    private

    def report_record_deletable?
      true
    end

    def delete_reportable_record!(moderator:)
      comment.delete_reported_comment!(moderator:)
    end
  end
end
