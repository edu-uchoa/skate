class StoresController < ApplicationController
  before_action :redirect_mentor_account # conta de mentor usa a área do mentor
  before_action :require_onboarding

  def show
    # In a real app, this would load the user's streaks, coins, and available rewards.
  end
end
