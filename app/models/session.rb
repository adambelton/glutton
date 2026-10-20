class Session < ApplicationRecord
  belongs_to :user

  validate :user_can_hold_session

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

  def user_can_hold_session
    user = User.find_by(id: user_id) if user_id
    errors.add(:user, :inactive) unless user&.active?
  end
end
