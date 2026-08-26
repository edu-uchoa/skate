class InstructionStep < ApplicationRecord
  belongs_to :maneuver

  validates :body, :position, presence: true
end
