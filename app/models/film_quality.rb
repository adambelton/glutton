class FilmQuality < ApplicationRecord
  module Dimensions
    EMOTIONAL_CHARACTER = "emotional_character".freeze
    TENSION_AND_RHYTHM = "tension_and_rhythm".freeze
    ENGAGEMENT = "engagement".freeze
    RELATIONSHIPS_AND_STAKES = "relationships_and_stakes".freeze
    INTENSITY_AND_EXPLICITNESS = "intensity_and_explicitness".freeze
    TONE = "tone".freeze
    RESOLUTION_AND_AFTERMATH = "resolution_and_aftermath".freeze

    ALL = [ EMOTIONAL_CHARACTER, TENSION_AND_RHYTHM, ENGAGEMENT, RELATIONSHIPS_AND_STAKES,
      INTENSITY_AND_EXPLICITNESS, TONE, RESOLUTION_AND_AFTERMATH ].freeze
  end

  has_many :analysis_qualities, dependent: :restrict_with_exception

  normalizes :name, with: ->(name) { name.strip }
  validates :name, presence: true
  validates :dimension, inclusion: { in: Dimensions::ALL }

  def self.find_or_create!(quality_candidate:)
    quality_candidate.validate!
    if quality_candidate.film_quality_id
      resolve_by_id!(quality_candidate:)
    else
      dimension = quality_candidate.dimension
      name = quality_candidate.name.strip
      resolve_by_name(dimension:, name:) || create_quality!(dimension:, name:)
    end
  end

  def self.resolve_by_id!(quality_candidate:)
    film_quality = find_by(id: quality_candidate.film_quality_id)
    unless film_quality && (quality_candidate.dimension.nil? || quality_candidate.dimension == film_quality.dimension)
      quality_candidate.errors.add(:film_quality_id, :invalid)
      raise ActiveModel::ValidationError.new(quality_candidate)
    end
    film_quality
  end

  def self.resolve_by_name(dimension:, name:)
    where(dimension:).where("lower(name) = lower(?)", name).first
  end

  def self.create_quality!(dimension:, name:)
    transaction(requires_new: true) { create!(dimension:, name:) }
  rescue ActiveRecord::RecordNotUnique => error
    constraint = error.cause&.result&.error_field(PG::Result::PG_DIAG_CONSTRAINT_NAME)
    raise unless constraint == "film_qualities_dimension_name"

    where(dimension:).where("lower(name) = lower(?)", name).first!
  end

  private_class_method :resolve_by_id!, :resolve_by_name, :create_quality!

  def readonly?
    persisted?
  end
end
