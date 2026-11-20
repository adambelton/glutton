module Library
  class TmdbFilmSearchRequest < Data.define(:provider_parameters, :offset, :number, :backwards, :legacy_batch)
    def self.parse(params)
      provider_parameters = TmdbFilmSearchParameters.parse(query: params[:query], page: params.fetch(:page, "1"),
        batch: params.fetch(:batch, "1"))
      return unless provider_parameters.present?

      offset = params.fetch(:offset, "0")
      number = params.fetch(:number, "1")
      backwards = params[:backwards]
      return unless offset.is_a?(String) && offset.valid_encoding? && offset.match?(/\A(?:0|[1-9]\d{0,2})\z/)
      return unless number.is_a?(String) && number.valid_encoding? && number.match?(/\A[1-9]\d{0,3}\z/)
      return if params.key?(:backwards) && backwards != "1"

      new(provider_parameters:, offset: offset.to_i, number: number.to_i, backwards: backwards == "1",
        legacy_batch: (provider_parameters.batch if params.key?(:batch)))
    end
  end
end
