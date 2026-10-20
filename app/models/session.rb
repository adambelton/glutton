class Session < ApplicationRecord
  belongs_to :user

  validate :user_can_hold_session

  def active?
    return false unless persisted?

    stored = Session.find_by(id: id)
    stored.present? && stored.user.active?
  end

  def self.resume(id:, user_id:)
    user = User.find_by(id: user_id)
    return unless user

    unless user.active?
      error = user.inactive_error
      raise error if error

      return
    end

    user if exists?(id:, user_id:)
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
