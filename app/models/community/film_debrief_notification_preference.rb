module Community
  class FilmDebriefNotificationPreference < ApplicationRecord
    self.table_name = "community_film_debrief_notification_preferences"

    UNRATED = "unrated".freeze
    RATING_OPTIONS = [ "brilliant", "pretty_good", "not_for_me", "garbage", UNRATED ].freeze

    belongs_to :user, class_name: "Identity::UserRegistered"

    scope :following_films, -> { RATING_OPTIONS.map { |value| where(value => true) }.reduce(:or) }

    def select_ratings!(values:)
      if (values - RATING_OPTIONS).any?
        errors.add(:base, :invalid_rating_selection)
        raise ActiveRecord::RecordInvalid, self
      end

      assign_attributes(RATING_OPTIONS.index_with { |value| values.include?(value) })
      save! if RATING_OPTIONS.any? { |value| will_save_change_to_attribute?(value) }
    end

    def selected_ratings
      RATING_OPTIONS.select { |value| self[value] }
    end

    def follows_rating?
      selected = selected_ratings
      return false if selected.empty?
      return true if selected == RATING_OPTIONS

      selected.include?(yield)
    end
  end
end
