class Film < ApplicationRecord
  has_many :film_qualities, dependent: :restrict_with_exception
  has_many :qualities, through: :film_qualities

  def tmdb_metadata?
    !!metadata.dig("tmdb", "details")
  end

  def fill_tmdb_metadata!(metadata:)
    update!(metadata: self.metadata.merge(metadata)) unless tmdb_metadata?
    self
  end

  validates :title, presence: true
  validates :tmdb_id, numericality: { only_integer: true, greater_than: 0 }, uniqueness: true, allow_nil: true
  validate :source_objects

  private

  def source_objects
    errors.add(:metadata, :invalid) unless metadata.is_a?(Hash)
    errors.add(:source_context, :invalid) unless source_context.is_a?(Hash)
  end
end
