module Community
  class PostCommunityCuration < Post
    TITLE_LIMIT = 120
    PROMPT_LIMIT = 2_000
    REFERENCE_LIMIT = 5

    belongs_to :author, class_name: "Identity::UserRegistered"
    has_many :film_endorsements, foreign_key: :post_id, inverse_of: :post

    normalizes :title, :prompt, with: ->(text) { text.strip }

    validates :title, presence: true, length: { maximum: TITLE_LIMIT }
    validates :prompt, presence: true, length: { maximum: PROMPT_LIMIT }

    def publish(reference_film_ids:, reference_comments:)
      valid?
      errors.add(:base, :too_many_references, count: REFERENCE_LIMIT) if reference_film_ids.size > REFERENCE_LIMIT
      errors.add(:base, :duplicate_references) if reference_film_ids.uniq != reference_film_ids
      return self if errors.any?

      reference_films = yield reference_film_ids
      if reference_films.size != reference_film_ids.size
        errors.add(:base, :unavailable_reference)
        return self
      end

      save!
      reference_films.each do |film|
        endorsement = film_endorsements.create!(film:, user: author)
        body = reference_comments[film.id].presence
        endorsement.add_initial_comment!(body:) if body.present?
      end
      self
    end

    def nominated_films
      film_endorsements.group_by(&:film)
        .sort_by { |film, endorsements| [ -endorsements.size, film.title.downcase, film.id ] }
    end
  end
end
