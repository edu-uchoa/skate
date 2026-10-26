module Mentor
  # Devolutiva do mentor, escrita no próprio cartão do vídeo da Zine do mentor.
  # "Na fila" envia a primeira (create): o aprendiz vê o resultado na tela de
  # devolutiva dele, a tarefa fica concluída e o vídeo passa para "Todos". Em
  # "Todos" quem escreveu pode revisar a devolutiva já enviada (update).
  class ReviewsController < BaseController
    include ActionView::RecordIdentifier

    before_action :set_training_session

    def create
      review = @training_session.ai_review || @training_session.build_ai_review(status: :pending)
      return redirect_to(card_in("todos"), notice: "Essa devolutiva já foi enviada.") if review.status_completed?
      unless @training_session.open_to?(current_user)
        return redirect_to(card_in("todos"), alert: "O aprendiz escolheu outro mentor para este vídeo. Sem resposta em 48h, o vídeo vai para a sua fila.")
      end

      if review.answer(current_user, **answer_params)
        redirect_to mentor_zine_path(aba: "fila"), notice: "Devolutiva enviada! O aprendiz já pode ver, e o vídeo foi para Todos."
      else
        form_with_errors(review)
      end
    end

    def update
      review = @training_session.ai_review
      return redirect_to(card_in("fila"), alert: "Esse vídeo ainda está na fila: envie a devolutiva por lá.") unless review&.status_completed?
      return redirect_to(card_in("todos"), alert: "Só quem escreveu a devolutiva pode revisar o texto.") unless review.revisable_by?(current_user)

      if review.revise(**answer_params)
        redirect_to card_in("todos"), notice: "Devolutiva revisada. O aprendiz já vê o texto novo."
      else
        form_with_errors(review)
      end
    end

    private

    # Só vídeos de aprendizes (nunca de outros mentores).
    def set_training_session
      @training_session = learner_clips.find(params[:video_id])
    end

    def card_in(tab) = mentor_zine_path(aba: tab, anchor: dom_id(@training_session, :mentor))

    # Volta o formulário com o que foi digitado e o erro, sem recarregar a página.
    def form_with_errors(review)
      respond_to do |format|
        format.turbo_stream do
          render turbo_stream: turbo_stream.replace(dom_id(@training_session, :review_form), partial: "mentor/reviews/form",
                   locals: { training_session: @training_session, review: review, values: answer_params }),
                 status: :unprocessable_entity
        end
        format.html { redirect_to card_in("fila"), alert: review.errors.full_messages.to_sentence }
      end
    end

    def answer_params
      attrs = params.require(:review).permit(:headline, :strengths, :mistake, :next_focus)
      { headline: attrs[:headline], strengths: attrs[:strengths], mistake: attrs[:mistake], next_focus: attrs[:next_focus] }
    end
  end
end
