module Community
  class PostCommunityCuration < Post
    TITLE_LIMIT = 120
    PROMPT_LIMIT = 2_000
    REFERENCE_LIMIT = 5
    RESPONSE_LIMIT = 5

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
      add_endorsements(member: author, films: reference_films, comments: reference_comments)
      self
    end

    def respond(member:, film_ids:, comments:)
      errors.clear
      unless (1..RESPONSE_LIMIT).cover?(film_ids.size)
        errors.add(:base, :response_film_count, count: RESPONSE_LIMIT)
        return self
      end

      films = yield film_ids.uniq
      validate_response_films(member:, film_ids:, films:)
      return self if errors.any?

      add_endorsements(member:, films:, comments:)
      touch
      self
    end

    def can_edit?(member:)
      author_id == member.id && PostingAccess.allowed?(user: member)
    end

    def edit_text(member:, title:, prompt:)
      raise Errors::CurationEditUnavailable unless can_edit?(member:)

      self.title = title
      self.prompt = prompt
      save(touch: false)
      self
    end

    def can_delete?(member:)
      author_id == member.id && member.active? && PreviewAccess.allowed?(user: member)
    end

    def delete_curation!(member:)
      raise Errors::CurationDeletionUnavailable unless can_delete?(member:)

      destroy!
    end

    def nominated_films
      film_endorsements.group_by(&:film)
        .sort_by { |film, endorsements| [ -endorsements.size, film.title.downcase, film.id ] }
    end

    private

    def validate_response_films(member:, film_ids:, films:)
      endorsed_films = film_endorsements.where(user: member, film_id: film_ids).preload(:film).map(&:film)
      repeated_ids = film_ids.tally.filter_map { |id, count| id if count > 1 }
      endorsed_ids = endorsed_films.map(&:id)
      known_films = (films + endorsed_films).index_by(&:id)
      (repeated_ids | endorsed_ids).each do |id|
        title = known_films[id]&.title || I18n.t("community.curation_responses.film_identifier", id:)
        error = endorsed_ids.include?(id) ? :already_endorsed_response_film : :repeated_response_film
        errors.add(:base, error, film: title)
      end
      if (film_ids - films.map(&:id)).any?
        errors.add(:base, :unavailable_response_film)
      end
    end

    def add_endorsements(member:, films:, comments:)
      films.each do |film|
        endorsement = film_endorsements.create!(film:, user: member)
        body = comments[film.id].presence
        endorsement.add_initial_comment!(body:) if body.present?
      end
    end
  end
end
