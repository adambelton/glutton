module Registry
  class FilmQualityEval < ApplicationRecord
    belongs_to :film
    has_many :film_qualities, dependent: :restrict_with_exception
    attr_readonly :film_id, :output

    validate :evaluation_output

    def self.record!(film:, assessment:)
      create!(film:, output: assessment.result)
    end

    def readonly?
      super || persisted?
    end

    def apply_initial_qualities!
      film.with_lock do
        raise Registry::AssignmentFailed.new(reason: :unready_film) unless film.has_source_context?
        raise Registry::AssignmentFailed.new(reason: :already_assigned) if film.has_film_qualities?
        unless source_current?
          raise Registry::AssignmentFailed.new(reason: :stale_inputs)
        end
        selected_qualities.each do |quality|
          film_qualities.create!(film:, quality:)
        end
        finish_application!("status" => "applied", "film_quality_ids" => film_qualities.map(&:id))
      end
      self
    end

    def record_application_failure!(reason:)
      finish_application!("status" => "failed", "reason" => reason.to_s)
    end

    def supports_association?(film_id:, quality_id:)
      output.fetch("status") == "completed" && self.film_id == film_id && output.fetch("selected_quality_ids").include?(quality_id)
    end

    private

    def source_current?
      source = output.fetch("source")
      source.fetch("title") == film.title && source.fetch("tmdb_id") == film.tmdb_id &&
        source.fetch("tmdb_metadata") == film.tmdb_metadata && source.fetch("wikidata_id") == film.wikidata_id &&
        source.fetch("wikipedia_context") == film.wikipedia_context
    end

    def selected_qualities
      raise Registry::AssignmentFailed.new(reason: :invalid_response) unless output.fetch("status") == "completed"
      qualities = Quality.where(id: output.fetch("selected_quality_ids")).index_by(&:id)
      output.fetch("selected_quality_ids").map do |quality_id|
        qualities.fetch(quality_id) { raise Registry::AssignmentFailed.new(reason: :stale_inputs) }
      end
    end

    def finish_application!(outcome)
      now = Time.current
      changed = self.class.where(id:, application: { "status" => "pending" }).update_all(
        application: outcome.merge("recorded_at" => now.utc.iso8601), updated_at: now)
      raise ActiveRecord::ReadOnlyRecord unless changed == 1
      reload
    end

    def evaluation_output
      errors.add(:output, :invalid) unless valid_output?
    end

    def valid_output?
      return false unless output.is_a?(Hash) && %w[assessed_at source definitions categories question_policy
        minimum_support model support evidence selected_quality_ids
        input_tokens calculated_cost_usd calls call_count selection_decisions status usage_complete].all? { |key| output.key?(key) }
      return false unless %w[completed failed].include?(output["status"])
      return false unless output["source"].is_a?(Hash) && output["source"]["wikipedia_context"].is_a?(Hash)
      return false unless %w[definitions categories calls selection_decisions].all? { |key| snapshot_records?(output[key]) }
      return false unless valid_support?(output["support"]) && valid_paragraph_references?(output["evidence"])

      quality_ids = output["selected_quality_ids"]
      quality_ids.is_a?(Array) && quality_ids.all? { |id| id.is_a?(Integer) && id.positive? } &&
        quality_ids.uniq.size == quality_ids.size
    end

    def valid_support?(support)
      support.is_a?(Hash) && support.values.all? { |value| value.is_a?(Numeric) && value.between?(0, 1) }
    end

    def valid_paragraph_references?(evidence)
      evidence.is_a?(Hash) && evidence.values.all? do |references|
        references.is_a?(Array) && references.all? { |id| id.is_a?(String) && id.present? }
      end
    end

    def snapshot_records?(records)
      records.is_a?(Array) && records.all? { |record| record.is_a?(Hash) }
    end
  end
end
