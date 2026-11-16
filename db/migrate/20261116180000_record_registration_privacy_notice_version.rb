class RecordRegistrationPrivacyNoticeVersion < ActiveRecord::Migration[8.1]
  def change
    [ :pending_registrations, :users ].each do |table|
      add_column table, :privacy_notice_version, :string
    end
  end
end
