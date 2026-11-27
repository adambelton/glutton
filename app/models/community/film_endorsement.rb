module Community
  class FilmEndorsement < ApplicationRecord
    belongs_to :post, class_name: "Community::PostCommunityCuration", inverse_of: :film_endorsements
    belongs_to :film, class_name: "Registry::Film"
    belongs_to :user, class_name: "Identity::UserRegistered", optional: true
    has_many :comments, inverse_of: :film_endorsement

    validates :user, presence: true, on: :create

    scope :active, -> { where(withdrawn_at: nil).where.not(user_id: nil) }
    scope :visible_nominations, -> {
      roots_with_replies = Comment.where(id: Comment.joins(:content).where.not(root_id: nil).select(:root_id))
      active.or(where(id: roots_with_replies.select(:film_endorsement_id)))
    }

    def active?
      withdrawn_at.nil? && user_id.present?
    end

    def add_opening_comment!(community_user:, body:)
      authorize_changes!(community_user:)
      raise Errors::CommentChangeUnavailable if opening_comment.present?

      content = build_opening_comment(community_user:, body:)
      content.comment.save!
      content
    end

    def opening_comment
      comments.find { |comment| comment.content.present? }
    end

    def withdraw!(community_user:)
      authorize_changes!(community_user:)
      opening_comment&.delete_comment!(community_user:)
      if comments.exists?
        update!(withdrawn_at: Time.current)
      else
        destroy!
      end
    end

    private

    def authorize_changes!(community_user:)
      raise Errors::PostingUnavailable unless active? && community_user.present? && user_id == community_user.user_id && community_user.ready_to_post?
    end

    def build_opening_comment(community_user:, body:)
      comments.build(post:).build_content(community_user:, body:)
    end
  end
end
