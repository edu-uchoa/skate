class DiagnosisBlocker < ApplicationRecord
  belongs_to :diagnosis

  # Cada trava vira uma recomendação diferente no plano (ver DiagnosisPlanner).
  enum :kind, {
    fear_of_falling: 0,   # medo de cair e me machucar
    shame: 1,             # vergonha de treinar na frente dos outros
    foot_technique: 2,    # não sei qual o movimento certo do pé
    no_place: 3           # falta de lugar adequado
  }, prefix: true

  validates :kind, presence: true, uniqueness: { scope: :diagnosis_id }
end
