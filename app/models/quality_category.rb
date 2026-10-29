class QualityCategory < ApplicationRecord
  has_many :qualities, dependent: :restrict_with_exception

  normalizes :name, with: ->(name) { name.strip }
  validates :key, presence: true, format: { with: /\A[a-z][a-z0-9_]*\z/ }, uniqueness: true
  validates :name, presence: true, uniqueness: { case_sensitive: false }
  validates :maximum_qualities, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validates :weight, numericality: { greater_than_or_equal_to: 0 }
  validate :immutable_key

  def remove!
    observed_version = lock_version
    with_lock do
      raise ActiveRecord::StaleObjectError.new(self, "destroy") unless lock_version == observed_version
      destroy!
    end
  end

  private

  def immutable_key
    errors.add(:key, :immutable) if persisted? && will_save_change_to_key?
  end
end
