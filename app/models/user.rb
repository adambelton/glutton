class User < ApplicationRecord
  validates :guest_expires_at, presence: true

  def self.create_guest!
    created_at = Time.current
    create!(created_at: created_at, guest_expires_at: created_at + 24.hours)
  end

  def guest_expired?
    guest_expires_at <= Time.current
  end
end
