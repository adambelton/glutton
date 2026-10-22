class Rating < ApplicationRecord
  module Values
    BRILLIANT = "brilliant".freeze
    I_ENJOYED_THAT = "i_enjoyed_that".freeze
    NOT_FOR_ME = "not_for_me".freeze
    GARBAGE = "garbage".freeze

    ALL = [ BRILLIANT, I_ENJOYED_THAT, NOT_FOR_ME, GARBAGE ].freeze
  end

  MAX_EXPRESSIONS = 20

  belongs_to :rating_film
  has_many :rating_expressions, -> { order(:id) }

  accepts_nested_attributes_for :rating_expressions, limit: MAX_EXPRESSIONS

  validate :recognized_value

  def publish_event!
    DomainEvents::Publish.call(user_id: rating_film.user_id, publisher: Ratings::EVENTS_PUBLISHING_DOMAIN,
      stream_key: "film:#{rating_film.film_id}", name: Ratings::Events::RATING_SUBMITTED, schema_version: 1,
      payload: { user_id: rating_film.user_id, film_id: rating_film.film_id, rating_id: id, value: })
  end

  private

  def recognized_value
    # External choices must match before Active Record's string coercion.
    errors.add(:value, :inclusion) unless Values::ALL.include?(value_before_type_cast)
  end
end
