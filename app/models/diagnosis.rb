class Diagnosis < ApplicationRecord
  belongs_to :user
  has_many :diagnosis_blockers, dependent: :destroy

  enum :level, { never_ridden: 0, can_push: 1, stuck_on_ollie: 2 }, prefix: true
  enum :setup, { no_board: 0, store_board: 1, skateshop_board: 2, other_board: 3 }, prefix: true

  STEPS = %w[level blockers setup].freeze

  def completed? = completed_at.present?

  def blocker_kinds = diagnosis_blockers.pluck(:kind)

  def blockers=(kinds)
    kinds = Array(kinds).reject(&:blank?)
    diagnosis_blockers.destroy_all
    kinds.each { |kind| diagnosis_blockers.build(kind: kind) }
  end

  # Primeiro passo ainda não respondido — usado para retomar o wizard.
  def next_step
    return "level"    if level.blank?
    return "blockers" if diagnosis_blockers.empty?
    return "setup"    if setup.blank?
    nil
  end

  def complete!
    update!(completed_at: Time.current)
  end
end
