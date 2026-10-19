class User < ApplicationRecord
  validates :type, presence: true

  def active?
    true
  end
end
