class Inspection < ApplicationRecord
  has_many :photos, dependent: :destroy
  has_one_attached :custom_logo

  validates :title, presence: true
end
