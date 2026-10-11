# Sessão de skate da ofensiva: um rolê marcado no mapa de Picos em que a pessoa
# gravou o vídeo de uma tarefa no horário do rolê e enviou o resultado.
#
# Guarda só o dia (o lugar do rolê some quando ele acaba). Fica validada com a
# devolutiva do mentor; até lá, já conta. Se o vídeo for apagado antes da
# devolutiva, a sessão sai junto (ClipsController).
class SkateSession < ApplicationRecord
  belongs_to :user
  belongs_to :training_session, optional: true

  scope :recent, -> { order(skated_on: :desc, created_at: :desc) }

  def validated? = validated_at.present?
end
