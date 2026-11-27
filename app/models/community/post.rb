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

    def spoiler_free?
      false
    end
  end
end
