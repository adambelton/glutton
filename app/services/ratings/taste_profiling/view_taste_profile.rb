module Ratings
  module TasteProfiling
    class ViewTasteProfile
      def self.call(user_id:)
        new(user_id:).call
      end

      def initialize(user_id:)
        @user_id = user_id
      end

      def call
        revision = TasteProfile.find_by(user_id: @user_id)&.current_revision
        { profile: revision&.profile, changes: changes(revision, current_notes),
          quality_rankings: quality_rankings }
      end

      private

      def quality_rankings
        totals = RatingQuality.current_rating_qualities_for_user(user_id: @user_id).group(:quality_id).sum(:score)
        positive, negative = totals.reject { |_, score| score.zero? }.partition { |_, score| score.positive? }
        top = positive.sort_by { |id, score| [ -score, id ] }.first(10).map(&:first)
        bottom = negative.sort_by { |id, score| [ score, id ] }.first(10).map(&:first)
        qualities = Registry::Quality.where(id: top + bottom).index_by(&:id)
        { top: ranked_qualities(top, totals, qualities), bottom: ranked_qualities(bottom, totals, qualities) }
      end

      def ranked_qualities(ids, totals, qualities)
        ids.map do |id|
          quality = qualities.fetch(id)
          { name: quality.name, definition: quality.match_rule, score: totals.fetch(id) }
        end
      end

      def current_notes
        Rating.current.joins(:rating_film).where(rating_films: { user_id: @user_id })
          .order(:id).pluck("rating_films.film_id", "ratings.notes").to_h.compact
      end

      def changes(revision, current)
        saved = (revision&.notes || []).to_h { |row| row.values_at("film_id", "text") }
        titles = Registry::Film.where(id: current.keys | saved.keys).pluck(:id, :title).to_h
        historical_titles = revision&.taste_profile_revision_eval&.output&.fetch("evidence", [])&.to_h do |row|
          [ row.fetch("film_id"), row.fetch("film_title") ]
        end || {}

        (current.keys | saved.keys).filter_map do |film_id|
          before, after = saved[film_id], current[film_id]
          next if before == after

          { title: titles[film_id] || historical_titles[film_id], added: Array(after), removed: Array(before) }
        end
      end
    end
  end
end
