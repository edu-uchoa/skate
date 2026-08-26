class Maneuver < ApplicationRecord
  belongs_to :learning_module
  belongs_to :prerequisite, class_name: "Maneuver", optional: true

  has_many :unlocks, class_name: "Maneuver", foreign_key: :prerequisite_id, dependent: :nullify
  has_many :instruction_steps, -> { order(:position) }, dependent: :destroy
  has_many :maneuver_progresses, dependent: :destroy
  has_many :training_sessions, dependent: :restrict_with_error

  enum :kind, { drill: 0, maneuver: 1, assessment: 2 }, prefix: true
  enum :difficulty, { beginner: 0, intermediate: 1, advanced: 2 }, prefix: true

  validates :code, :slug, :name, presence: true, uniqueness: { case_sensitive: false }

  scope :ordered, -> { joins(:learning_module).order("learning_modules.position", :position) }

  accepts_nested_attributes_for :instruction_steps

  def to_param = slug

  def label = "#{code} · #{name}"
end
