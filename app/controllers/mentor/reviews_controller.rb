module Mentor
  # Tela de resposta: o mentor assiste ao vídeo e escreve a devolutiva em três partes.
  # Ao enviar, o aprendiz vê o resultado na tela de devolutiva que ele já acompanha.
  class ReviewsController < BaseController
    before_action :set_review

    def edit
      return redirect_to(mentor_zine_path(aba: "todos"), notice: "Essa devolutiva já foi enviada.") unless @review.awaiting_mentor?

      # O aprendiz passa a ver "O mentor está vendo seu vídeo".
      @review.status_processing! if @review.status_pending?
    end

    def update
      return redirect_to(mentor_zine_path(aba: "todos"), notice: "Essa devolutiva já foi enviada.") unless @review.awaiting_mentor?

      if @review.answer(current_user, **answer_params)
        redirect_to mentor_zine_path, notice: "Devolutiva enviada! O aprendiz já pode ver."
      else
        render :edit, status: :unprocessable_entity
      end
    end

    private

    # Só devolutivas de vídeos de aprendizes (nunca de outros mentores).
    def set_review
      @review = AiReview.find(params[:id])
      @training_session = learner_clips.find(@review.training_session_id)
    end

    def answer_params
      attrs = params.require(:review).permit(:headline, :strengths, :mistake, :next_focus)
      { headline: attrs[:headline], strengths: attrs[:strengths], mistake: attrs[:mistake], next_focus: attrs[:next_focus] }
    end
  end
end
