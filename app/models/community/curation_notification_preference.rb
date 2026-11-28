module Community
  class CurationNotificationPreference < ApplicationRecord
    self.table_name = "community_curation_notification_preferences"

    belongs_to :user, class_name: "Identity::UserRegistered"

    def change_settings!(authored_curations:, endorsed_film_comments:)
      self.authored_curations = authored_curations unless authored_curations.nil?
      self.endorsed_film_comments = endorsed_film_comments unless endorsed_film_comments.nil?
      save! if will_save_change_to_authored_curations? || will_save_change_to_endorsed_film_comments?
    end
  end
end
