module Community
  module CurationFilmSelectionParameters
    def self.parse(ids:, comments:)
      ids = [] if ids.nil?
      unless ids.is_a?(Array) && ids.all? { |id| valid_film_id?(id) }
        raise ActionController::BadRequest
      end
      unless comments.nil? || (comments.is_a?(ActionController::Parameters) &&
          comments.each_pair.all? { |id, body| ids.include?(id) && body.is_a?(String) })
        raise ActionController::BadRequest
      end

      [ ids.map(&:to_i), comments.nil? ? {} : comments.each_pair.to_h.transform_keys(&:to_i) ]
    end

    def self.valid_film_id?(id)
      id.is_a?(String) && id.match?(/\A[1-9][0-9]{0,18}\z/) && id.to_i <= 2**63 - 1
    end
  end
end
