module Community
  class CodeOfConductAcceptance < ApplicationRecord
    self.table_name = "community_code_of_conduct_acceptances"

    belongs_to :user, class_name: "Identity::UserRegistered"

    validates :code_version, inclusion: { in: -> { CodeOfConduct::VERSIONS } }
    validates :accepted_at, presence: true

    def self.record!(member:, code:)
      find_or_create_by!(user: member, code_version: code.version) do |acceptance|
        acceptance.accepted_at = Time.current
      end
    end
  end
end
