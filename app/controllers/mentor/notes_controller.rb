module Mentor
  # Observações da equipe de mentores sobre o aprendiz (Perfil do aprendiz). Qualquer
  # mentor escreve; apaga quem escreveu ou a administração.
  class NotesController < BaseController
    before_action :set_learner

    def create
      body = params.dig(:mentor_note, :body)
      note = @learner.mentor_notes.build(author: current_user, body: body)

      if note.save
        redirect_to back_to_notes, notice: "Observação salva. Só os mentores veem."
      else
        flash[:mentor_note] = body.to_s.first(MentorNote::BODY_LENGTH * 2) # volta o que foi escrito, para corrigir
        redirect_to back_to_notes, alert: note.errors.full_messages.to_sentence
      end
    end

    def destroy
      note = @learner.mentor_notes.find(params[:id])
      return not_found unless note.deletable_by?(current_user)

      note.destroy!
      redirect_to back_to_notes, notice: "Observação apagada."
    end

    private

    # Só contas de aprendiz (mentor não anota sobre outro mentor).
    def set_learner
      @learner = User.role_learner.find(params[:learner_id])
    end

    def back_to_notes = mentor_learner_path(@learner, anchor: "observacoes")
  end
end
