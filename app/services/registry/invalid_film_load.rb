module Registry
  class InvalidFilmLoad < ArgumentError
    attr_reader :reason

    def initialize(reason:)
      @reason = reason
      super(I18n.t("registry.loading.errors.#{reason}"))
    end
  end
end
