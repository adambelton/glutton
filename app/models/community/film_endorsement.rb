module Community
  class FilmEndorsement < ApplicationRecord
    belongs_to :post, class_name: "Community::PostCommunityCuration", inverse_of: :film_endorsements
    belongs_to :film, class_name: "Registry::Film"
    belongs_to :user, class_name: "Identity::UserRegistered"
    has_one :comment, inverse_of: :film_endorsement

    def add_initial_comment!(body:)
      create_comment!(post:).create_content!(author: user, body:)
    end
  end
end
