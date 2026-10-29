class Quality < ApplicationRecord
  belongs_to :quality_category
  has_many :film_qualities, dependent: :restrict_with_exception
  has_many :films, through: :film_qualities

  normalizes :name, with: ->(name) { name.strip }
  validates :name, presence: true, uniqueness: { scope: :quality_category_id, case_sensitive: false, on: :update }
  validate :immutable_name

  def recategorise!(quality_category:)
    observed_version = lock_version
    with_lock do
      raise ActiveRecord::StaleObjectError.new(self, "update") unless lock_version == observed_version
      if quality_category_id == quality_category.id
        errors.add(:quality_category, :unchanged)
        raise ActiveRecord::RecordInvalid.new(self)
      end
      update!(quality_category:)
    end
    self
  end

  private

  def immutable_name
    errors.add(:name, :immutable) if persisted? && will_save_change_to_name?
  end
end
