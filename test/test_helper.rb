ENV["RAILS_ENV"] ||= "test"
require_relative "../config/environment"
require "rails/test_help"

module ActiveSupport
  class TestCase
    # Setup all fixtures in test/fixtures/*.yml for all tests in alphabetical order.
    fixtures :all

    def create_community_account(**attributes)
      profile = attributes.extract!(:community_username, :community_avatar_preset)
      Identity::UserRegistered.create!(**attributes).tap do |account|
        if profile.values.any?(&:present?) || account.community_code_of_conduct_accepted_at.present?
          Community::CommunityUser.create!(user: account, **profile)
        end
      end
    end
  end
end
