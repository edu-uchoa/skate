# Lista de mentores para o aprendiz escolher quem avalia o vídeo (telas Gravar e
# Resultado), do mais bem avaliado para o menos, com a média de rolamentos de cada um.
module MentorChoice
  extend ActiveSupport::Concern

  private

  # chosen_id: o que veio no formulário; sem ele, já vem marcado o último mentor que a
  # pessoa escolheu (se ele ainda está na lista).
  def load_mentor_choice(chosen_id = nil)
    mentors = User.available_mentors
    @mentor_scores = MentorRating.for(mentors)
    @mentors = MentorRating.ranked(mentors, @mentor_scores)
    @chosen_mentor_id = chosen_id.presence&.to_i ||
                        current_user.training_sessions.where.not(mentor_id: nil).order(:id).last&.mentor_id
  end
end
