module Onboarding
  # Wizard de 3 passos: nível -> travas -> setup.
  class DiagnosesController < ApplicationController
    before_action :require_age_gate
    before_action :set_diagnosis

    def show
      @step = requested_step
      render @step
    end

    def update
      @step = requested_step

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
