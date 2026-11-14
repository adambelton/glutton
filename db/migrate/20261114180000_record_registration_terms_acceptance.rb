class RecordRegistrationTermsAcceptance < ActiveRecord::Migration[8.1]
  def change
    [ :pending_registrations, :users ].each do |table|
      add_column table, :terms_version, :string
      add_column table, :terms_accepted_at, :datetime
      add_check_constraint table, "(terms_version IS NULL) = (terms_accepted_at IS NULL)",
        name: "#{table}_complete_terms_acceptance"
    end
  end
end
