class Film < ApplicationRecord
  validates :title, presence: true
  validates :tmdb_id, numericality: { only_integer: true, greater_than: 0 }, uniqueness: true, allow_nil: true
  validate :metadata_is_object

  private

  def metadata_is_object
    errors.add(:metadata, :invalid) unless metadata.is_a?(Hash)
  end
end
