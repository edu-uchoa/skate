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
        @user.errors.add(:birth_year, "informe o ano de nascimento")
        return render :show, status: :unprocessable_entity
      end

      unless @user.old_enough?
        @user.errors.add(:base, "O Skate é restrito a maiores de #{User::MINIMUM_AGE} anos.")
        return render :show, status: :unprocessable_entity
      end

      @user.terms_accepted_at = Time.current
      @user.save!
      redirect_to onboarding_diagnosis_path
    end
  end
end
