module Community
  class Post < ApplicationRecord
    has_many :comments, inverse_of: :post

    def require_view_access!(viewer:)
      Membership::Access.require!(user: viewer)
    end

    def reportable_attributes
      {}
    end

    def discussion_comment(id)
      comments.find(id)
    end

    def report_reasons
      Reportable::REASONS_WITHOUT_SPOILERS
    end
  end
end
