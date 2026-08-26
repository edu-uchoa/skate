# "Module" é reservado em Ruby, então o módulo da trilha é LearningModule.
class LearningModule < ApplicationRecord
  has_many :maneuvers, -> { order(:position) }, dependent: :destroy

  validates :code, :name, presence: true, uniqueness: { case_sensitive: false }

  scope :ordered, -> { order(:position) }

  def to_param = code
end
