class StoresController < ApplicationController
  before_action :require_onboarding

  def show
    # In a real app, this would load the user's streaks, coins, and available rewards.
  end
end
