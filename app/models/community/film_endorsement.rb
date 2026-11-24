module Community
  class FilmEndorsement < ApplicationRecord
    belongs_to :post, class_name: "Community::PostCommunityCuration", inverse_of: :film_endorsements
    belongs_to :film, class_name: "Registry::Film"
    belongs_to :user, class_name: "Identity::UserRegistered"
    has_many :comments, inverse_of: :film_endorsement

    scope :active, -> { where(withdrawn_at: nil) }
    scope :visible_nominations, -> {
      roots_with_replies = Comment.where(id: Comment.joins(:content).where.not(root_id: nil).select(:root_id))
      active.or(where(id: roots_with_replies.select(:film_endorsement_id)))
    }

    def active?
      withdrawn_at.nil?
    end

    def add_initial_comment!(body:)
      content = build_opening_comment(body:)
      content.comment.save!
      content
    end

    def opening_comment
      comments.find { |comment| comment.content.present? }
    end

    def revise_opening_comment!(member:, body:)
      authorize_changes!(member:)
      opening_comment.content.edit_body!(body:)
    end

    def withdraw!(member:)
      authorize_changes!(member:)
      opening_comment&.delete_comment!(member:)
      if comments.exists?
        update!(withdrawn_at: Time.current)
      else
        destroy!
      end
    end

    private

    def authorize_changes!(member:)
      raise Errors::PostingUnavailable unless active? && user_id == member.id && PostingAccess.allowed?(user: member)
    end

    def build_opening_comment(body:)
      comments.build(post:).build_content(author: user, body:)
    end
  end
end
