module Community
  module CurationFilmSelectionParameters
    def self.parse(ids:, comments:)
      ids = [] if ids.nil?
      unless ids.is_a?(Array) && ids.all? { |id| FilmId.valid?(id) }
        raise ActionController::BadRequest
      end
      submitted_ids = ids.to_set
      unless comments.nil? || (comments.is_a?(ActionController::Parameters) &&
          comments.each_pair.all? { |id, body| submitted_ids.include?(id) && body.is_a?(String) })
        raise ActionController::BadRequest
      end

      [ ids.map(&:to_i), comments.nil? ? {} : comments.each_pair.to_h.transform_keys(&:to_i) ]
    end
  end
end
