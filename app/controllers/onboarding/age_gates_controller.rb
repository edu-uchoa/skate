module Onboarding
  # Aviso de risco + porta de idade (13+).
  class AgeGatesController < ApplicationController
    def show
      @user = current_user
    end

    def update
      @user = current_user
      @user.assign_attributes(birth_year: params.dig(:user, :birth_year).presence)

      if @user.birth_year.blank?
        @user.errors.add(:base, "Informe o ano de nascimento.")
        return render :show, status: :unprocessable_entity
      end

      unless @user.old_enough?
        @user.errors.add(:base, "O FlipaAi é restrito a maiores de #{User::MINIMUM_AGE} anos.")
        return render :show, status: :unprocessable_entity
      end

      unless params[:accept_terms] == "1"
        @user.errors.add(:base, "Para continuar, leia e aceite os Termos de Uso e a Política de Privacidade.")
        return render :show, status: :unprocessable_entity
      end

      @user.terms_accepted_at = Time.current
      @user.save!
      redirect_to onboarding_diagnosis_path
    end
  end
end
