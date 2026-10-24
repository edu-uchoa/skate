class TrainingSessionsController < ApplicationController
  include MentorChoice

  before_action :require_onboarding
  before_action :set_training_session, only: %i[show update start result submit]

  # Checklist de segurança antes de gravar.
  def new
    @maneuver = Maneuver.find_by!(slug: params[:maneuver_slug])
    @training_session = current_user.training_sessions.build(maneuver: @maneuver, scheduled_on: Date.current)
  end

  def create
    @maneuver = Maneuver.find_by!(slug: params[:maneuver_slug])
    @training_session = current_user.training_sessions.build(
      maneuver: @maneuver, scheduled_on: Date.current, status: :scheduled
    )
    @training_session.assign_attributes(checklist_params)

    unless @training_session.checklist_complete?
      @training_session.errors.add(:base, "Marque os três itens do checklist de segurança para começar.")
      return render :new, status: :unprocessable_entity
    end

    # "Gravar o vídeo do treino": vai para a tela Gravar com a manobra e o checklist já
    # marcados. O treino nasce lá, junto com o vídeo.
    return redirect_to new_recording_path(maneuver_slug: @maneuver.slug, checklist: "ok") if params[:gravar].present?

    if @training_session.save && @training_session.start!
      redirect_to result_training_session_path(@training_session)
    else
      render :new, status: :unprocessable_entity
    end
  end

  def show
    redirect_to result_training_session_path(@training_session)
  end

  # Marca itens do checklist sem sair da tela (Turbo).
  def update
    @training_session.update(checklist_params)
    render :new, status: :ok
  end

  def start
    if @training_session.start!
      redirect_to result_training_session_path(@training_session)
    else
      redirect_to new_maneuver_training_session_path(@training_session.maneuver),
                  alert: "Complete o checklist de segurança antes de começar."
    end
  end

  # Tela "Registro do resultado". Sem vídeo ainda, dá para mandar um daqui, escolhendo
  # o mentor que vai avaliar.
  def result
    load_mentor_choice unless @training_session.clip.attached?
  end

  def submit
    @training_session.assign_attributes(result_params)
    if result_params[:clip].present? && @training_session.mentor.nil?
      @training_session.mentor = User.available_mentor(params.dig(:training_session, :mentor_id))
    end

    if @training_session.save
      @training_session.submit!(offline: params[:offline].present?)
      if @training_session.ai_review.blank? && !@training_session.status_queued?
        flash[:notice] = "Resultado salvo. A tarefa é concluída quando um mentor responde a um vídeo seu."
      end
      redirect_to next_screen_for(@training_session)
    else
      load_mentor_choice(params.dig(:training_session, :mentor_id))
      render :result, status: :unprocessable_entity
    end
  end

  private

  def set_training_session
    @training_session = current_user.training_sessions.find(params[:id])
  end

  def checklist_params
    params.fetch(:training_session, {}).permit(:gear_checked, :ground_clear, :space_safe)
  end

  def result_params
    params.require(:training_session).permit(:outcome, :notes, :clip)
  end

  def next_screen_for(session)
    return training_session_path(session) if session.status_queued?
    return training_session_ai_review_path(session) if session.ai_review.present?
    track_path
  end
end
