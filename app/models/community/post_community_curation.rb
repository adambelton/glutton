module Community
  class PostCommunityCuration < Post
    include Reportable

    TITLE_LIMIT = 120
    DESCRIPTION_LIMIT = 2_000
    ENDORSERS_FOR_PROTECTION = 3
    COMMENTS_FOR_PROTECTION = 5
    COMMENTERS_FOR_PROTECTION = 2

    belongs_to :author, class_name: "Identity::UserRegistered", optional: true
    has_many :film_endorsements, foreign_key: :post_id, inverse_of: :post
    has_many :visible_film_endorsements, -> { visible_nominations }, class_name: "Community::FilmEndorsement", foreign_key: :post_id

    normalizes :title, :description, with: ->(text) { text.strip }
    normalizes :additional_description, with: ->(text) { text.strip.presence }

    validates :title, presence: true, length: { maximum: TITLE_LIMIT }
    validates :description, presence: true, length: { maximum: DESCRIPTION_LIMIT }
    validates :additional_description, length: { maximum: DESCRIPTION_LIMIT }, allow_nil: true, if: :will_save_change_to_additional_description?
    validates :author, presence: true, on: :create

    # The deletion owner follows the account until the curation becomes protected.
    before_create { self.deletable_author_id = author_id }

    def reportable_attributes
      { "title" => title, "description" => description, "additional_description" => additional_description }.compact_blank
    end

    def discussion_comment(id)
      comment = super
      film_id = Discussions::CurationDiscussion.film_id_for(comment)
      raise Errors::NominationUnavailable unless visible_film_endorsements.exists?(film_id:)

      comment
    end

    def spoiler_free?
      true
    end

    def reported_member
      author
    end

    def publish(reference_film_ids:, reference_comments:)
      valid?
      errors.add(:base, :duplicate_references) if reference_film_ids.uniq != reference_film_ids
      validate_opening_comment_lengths(reference_comments)
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
      validate_opening_comment_lengths(comments)
      return self if errors.any?

      added_comment = false
      endorsements.each do |film_id, endorsement|
        unless selected_ids.include?(film_id)
          endorsement.withdraw!(member:)
          next
        end

        body = comments[film_id].to_s.strip.presence
        next unless body.present?

        endorsement.add_opening_comment!(member:, body:)
        added_comment = true
      end
      add_endorsements(member:, films:, comments:)
      if films.any? || added_comment
        protect_from_contributions!
        touch
      end
      self
    end

    def can_edit?(member:)
      !protected? && author_id == member.id && Membership::PostingAccess.allowed?(user: member)
    end

    def edit_text(member:, title:, description:)
      raise Errors::CurationEditUnavailable unless can_edit?(member:)

      self.title = title
      self.description = description
      save(touch: false)
      self
    end

    def can_delete?(member:)
      !protected? && author_id == member.id && member.active? && Membership::Access.allowed?(user: member)
    end

    def delete_curation!(member:)
      raise Errors::CurationDeletionUnavailable unless can_delete?(member:)

      destroy!
    end

    def protected?
      protected_at.present?
    end

    def protect_from_contributions!
      return if protected?

      endorsers = film_endorsements.active.where.not(user_id: author_id).distinct.limit(ENDORSERS_FOR_PROTECTION).pluck(:user_id)
      if endorsers.size == ENDORSERS_FOR_PROTECTION || comment_protection_threshold_met?
        update!(protected_at: Time.current, deletable_author_id: nil)
      end
    end

    def can_edit_additional_description?(member:)
      protected? && author_id == member.id && Membership::PostingAccess.allowed?(user: member)
    end

    def edit_additional_description(member:, additional_description:)
      raise Errors::CurationEditUnavailable unless can_edit_additional_description?(member:)

      self.additional_description = additional_description
      save(touch: false)
      self
    end

    def can_disassociate?(member:)
      protected? && author_id == member.id && member.active? && Membership::Access.allowed?(user: member)
    end

    def disassociate!(member:)
      raise Errors::CurationEditUnavailable unless can_disassociate?(member:)

      self.author = nil
      save!(touch: false)
    end

    def nominated_films
      visible_film_endorsements.group_by(&:film)
        .transform_values { |endorsements| endorsements.select(&:active?) }
        .sort_by { |film, endorsements| [ -endorsements.size, film.title.downcase, film.id ] }
    end

    private

    def validate_opening_comment_lengths(comments)
      if comments.values.any? { |body| CommentContent.body_too_long?(body) }
        errors.add(:base, :opening_comment_too_long, count: CommentContent::BODY_LIMIT)
      end
    end

    def comment_protection_threshold_met?
      other_comments = CommentContent.joins(:comment).where(comments: { post_id: id }).where.not(author_id:)
      other_comments.limit(COMMENTS_FOR_PROTECTION).count == COMMENTS_FOR_PROTECTION &&
        other_comments.distinct.limit(COMMENTERS_FOR_PROTECTION).pluck(:author_id).size == COMMENTERS_FOR_PROTECTION
    end

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
        if comments.key?(id) && endorsements.fetch(id).opening_comment.present?
          errors.add(:base, :edit_opening_comment_on_post, film: known_films.fetch(id).title)
        end
      end
    end

    def add_endorsements(member:, films:, comments:)
      films.each do |film|
        endorsement = film_endorsements.create!(film:, user: member)
        body = comments[film.id].to_s.strip.presence
        endorsement.add_opening_comment!(member:, body:) if body.present?
      end
    end
  end
end
