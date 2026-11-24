module Community
  class PostCommunityCuration < Post
    TITLE_LIMIT = 120
    PROMPT_LIMIT = 2_000

    belongs_to :author, class_name: "Identity::UserRegistered"
    has_many :film_endorsements, foreign_key: :post_id, inverse_of: :post
    has_many :visible_film_endorsements, -> { visible_nominations }, class_name: "Community::FilmEndorsement", foreign_key: :post_id

    normalizes :title, :prompt, with: ->(text) { text.strip }

    validates :title, presence: true, length: { maximum: TITLE_LIMIT }
    validates :prompt, presence: true, length: { maximum: PROMPT_LIMIT }

    def publish(reference_film_ids:, reference_comments:)
      valid?
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

    def edit_endorsements(member:, endorsements:, film_ids:, comments:)
      errors.clear
      errors.add(:base, :endorsement_film_required) if endorsements.empty? && film_ids.empty?

      selected_ids = film_ids.to_set
      additions = selected_ids.to_a - endorsements.keys
      films = yield additions
      validate_endorsement_selection(endorsements:, film_ids:, additions:, films:, comments:)
      return self if errors.any?

      added_comment = false
      endorsements.each do |film_id, endorsement|
        unless selected_ids.include?(film_id)
          endorsement.withdraw!(member:)
          next
        end

        body = comments[film_id].to_s.strip.presence
        next unless body.present?

        opening = endorsement.opening_comment
        if opening.present?
          endorsement.revise_opening_comment!(member:, body:) if opening.content.body != body
        else
          endorsement.add_initial_comment!(body:)
          added_comment = true
        end
      end
      add_endorsements(member:, films:, comments:)
      touch if films.any? || added_comment
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
      visible_film_endorsements.group_by(&:film)
        .transform_values { |endorsements| endorsements.select(&:active?) }
        .sort_by { |film, endorsements| [ -endorsements.size, film.title.downcase, film.id ] }
    end

    private

    def validate_endorsement_selection(endorsements:, film_ids:, additions:, films:, comments:)
      known_films = (films + endorsements.values.map(&:film)).index_by(&:id)
      repeated_ids = film_ids.tally.filter_map { |id, count| id if count > 1 }
      repeated_ids.each do |id|
        title = known_films[id]&.title || I18n.t("community.curation_endorsements.film_identifier", id:)
        errors.add(:base, :repeated_endorsement_film, film: title)
      end
      if (additions - films.map(&:id)).any?
        errors.add(:base, :unavailable_endorsement_film)
      end
      (film_ids.uniq & endorsements.keys).each do |id|
        if endorsements.fetch(id).opening_comment.present? && comments[id].blank?
          errors.add(:base, :remove_opening_comment_on_post, film: known_films.fetch(id).title)
        end
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
