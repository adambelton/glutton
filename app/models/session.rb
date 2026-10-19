class Session < ApplicationRecord
  belongs_to :user

  validate :owner_can_hold_session

  def active?
    return false unless persisted?

    stored = self.class.find_by(id: id)
    stored.present? && stored.user.active?
  end

  def self.revoke(id:)
    where(id: id).delete_all
    true
  end

  private

  def owner_can_hold_session
    owner = User.find_by(id: user_id) if user_id
    errors.add(:user, "must be active") unless owner&.active?
  end
end
