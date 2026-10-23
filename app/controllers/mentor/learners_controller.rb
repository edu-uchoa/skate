module Mentor
  # Perfil do aprendiz para os mentores (abre tocando no nome, no chat e na Zine do
  # mentor): as respostas das 3 perguntas do cadastro, o nível, a ofensiva, onde ele
  # está na trilha e as observações da equipe de mentores, que ele não vê no app.
  class LearnersController < BaseController
    def show
      @learner = User.role_learner.includes(diagnosis: :diagnosis_blockers).find(params[:id])
      @stats = ProfileStats.new(@learner)
      @streak = Streak.new(@learner)
      @current_maneuver = TrackProgression.new(@learner).current_maneuver # só lê: não mexe na trilha dele
      @notes = @learner.mentor_notes.includes(:author).recent_first
    end
  end
end
