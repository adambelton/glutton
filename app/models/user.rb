class User < ApplicationRecord
  validates :type, presence: true

  def expired?
    false
  end
end
