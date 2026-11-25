module Community
  module FilmId
    def self.valid?(value)
      value.is_a?(String) && value.match?(/\A[1-9][0-9]{0,18}\z/) && value.to_i <= 2**63 - 1
    end
  end
end
