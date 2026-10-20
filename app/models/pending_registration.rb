require "digest"

class PendingRegistration < ApplicationRecord
  belongs_to :guest_user, class_name: "User", optional: true

  scope :expired, -> { where(arel_table[:created_at].lteq(24.hours.ago)) }

  generates_token_for :email_confirmation, expires_in: 1.hour do
    Digest::SHA256.hexdigest([ email_address, password_digest ].to_json)
  end

  has_secure_password reset_token: false
  normalizes :email_address, with: ->(email) { email.strip.downcase }

  validates :email_address, presence: true, format: { with: URI::MailTo::EMAIL_REGEXP }
  validates :password_digest, presence: true
  validates :password, presence: true, on: :create
  validates :password, length: { minimum: 15 }, allow_nil: true
  validates :password_confirmation, presence: true, if: -> { password.present? }

  validates :confirmation_delivery_attempts, numericality: { only_integer: true, greater_than_or_equal_to: 0, less_than_or_equal_to: 5 }

  validate :email_is_unregistered, on: :create

  def expires_at
    created_at + 24.hours
  end

  def active?
    return false unless persisted? && expires_at > Time.current

    guest_user_id.nil? || User.find_by(id: guest_user_id)&.active?
  end

  def available_to?(user:)
    active? && (user.nil? || user.can_register?) &&
      (guest_user_id.nil? || guest_user_id == user&.id) &&
      !UserRegistered.exists?(email_address:)
  end

  def attach_to!(user:)
    raise Identity::RegistrationUnavailable unless user.can_register? && active?
    if (guest_user_id.present? && guest_user_id != user.id) ||
        self.class.where(guest_user_id: user.id).where.not(id:).exists?
      raise Identity::RegistrationConflict
    end

    update!(guest_user_id: user.id) if guest_user_id.nil?
    self
  end

  private

  def email_is_unregistered
    return if email_address.blank? || errors[:email_address].any?

    errors.add(:email_address, :registered) if UserRegistered.exists?(email_address: email_address)
  end
end
