module Onboarding
  # Wizard de 3 passos: nível -> travas -> setup.
  class DiagnosesController < ApplicationController
    before_action :redirect_mentor_account # a conta de mentor não faz o cadastro de aprendiz
    before_action :require_age_gate
    before_action :set_diagnosis

    # Cada pergunta tem o seu endereço (?step=level, blockers, setup): assim o "voltar" do
    # navegador (e o botão Voltar da tela) leva à pergunta anterior, e não de novo à mesma.
    def show
      return redirect_to(onboarding_diagnosis_path(step: requested_step)) if params[:step].blank?

      @step = requested_step
      render @step
    end

    # Pergunta enviada sem resposta: avisa e fica na mesma tela (antes, a tela só
    # recarregava, sem dizer o que faltava).
    UNANSWERED = {
      "level"    => "Escolha o seu nível hoje para continuar.",
      "blockers" => "Marque pelo menos uma opção (pode marcar várias).",
      "setup"    => "Escolha como é o seu skate hoje para continuar."
    }.freeze

    def update
      @step = requested_step
      if Array(params.dig(:diagnosis, @step)).compact_blank.empty?
        @diagnosis.errors.add(:base, UNANSWERED.fetch(@step))
        return render(@step, status: :unprocessable_entity)
      end

      case @step
      when "level"    then @diagnosis.level = params.dig(:diagnosis, :level)
      when "blockers" then @diagnosis.blockers = params.dig(:diagnosis, :blockers)
      when "setup"    then @diagnosis.setup = params.dig(:diagnosis, :setup)
      end

      if @diagnosis.save
        advance
      else
        render @step, status: :unprocessable_entity
      end
    end

    # Tela "Validação de diagnóstico".
    def summary
      redirect_to onboarding_diagnosis_path and return unless @diagnosis.completed?
      @planner = DiagnosisPlanner.new(@diagnosis)
    end

    private

    def set_diagnosis
      @diagnosis = current_user.diagnosis || current_user.create_diagnosis!
    end

    def requested_step
      step = params[:step].presence || @diagnosis.next_step || "level"
      Diagnosis::STEPS.include?(step) ? step : "level"
    end

    def advance
      if @diagnosis.next_step.nil?
        @diagnosis.complete!
        DiagnosisPlanner.new(@diagnosis).apply!
        redirect_to summary_onboarding_diagnosis_path
      else
        redirect_to onboarding_diagnosis_path(step: @diagnosis.next_step)
      end
    end
  end
end
