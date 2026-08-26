class TrainingSessionsController < ApplicationController
  before_action :require_age_gate
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

  # Tela "Registro do resultado".
  def result; end

  def submit
    @training_session.assign_attributes(result_params)

    if @training_session.save
      @training_session.submit!(offline: params[:offline].present?)
      redirect_to next_screen_for(@training_session)
    else
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
