require "test_helper"

class ProfileStatsTest < ActiveSupport::TestCase
  setup do
    travel_to Time.zone.parse("2026-10-12 15:00 -03:00")
    @user = User.create!(time_zone: "America/Sao_Paulo")
    base   = LearningModule.create!(code: "0", name: "BASE", position: 0)
    tricks = LearningModule.create!(code: "3", name: "PRIMEIRAS MANOBRAS", position: 3)
    @setup    = Maneuver.create!(learning_module: base, code: "0.1", slug: "t-setup", name: "SETUP", position: 0)
    @shove_it = Maneuver.create!(learning_module: tricks, code: "3.0", slug: "t-shove-it", name: "SHOVE-IT", position: 0)
    @no_comply = Maneuver.create!(learning_module: tricks, code: "3.1", slug: "t-no-comply", name: "NO COMPLY", position: 1)
  end

  def stats = ProfileStats.new(@user)

  def train(maneuver, at:)
    @user.training_sessions.create!(maneuver: maneuver, scheduled_on: at.to_date, status: :submitted, submitted_at: at)
  end

  test "XP cresce por módulo e só vem de tarefa concluída pelo mentor" do
    assert_equal 50, ProfileStats.xp_for(@setup)
    assert_equal 200, ProfileStats.xp_for(@shove_it)

    progression = TrackProgression.new(@user).sync!
    progression.complete!(@setup)
    @user.maneuver_progresses.find_by!(maneuver: @shove_it).update!(status: :skipped)

    assert_equal 50, stats.xp, "tarefa pulada não vale XP"
    assert_equal 1, stats.completed_count
  end

  test "cada nível pede mais XP que o anterior" do
    assert_equal [ 0, 100, 300, 600, 1000 ], (1..5).map { |level| ProfileStats.threshold(level) }

    { 0 => 1, 99 => 1, 100 => 2, 299 => 2, 300 => 3, 1000 => 5 }.each do |xp, level|
      assert_equal level, ProfileStats.level_for(xp).number, "#{xp} XP"
    end
    assert_equal 50, ProfileStats.level_for(200).progress(200), "metade do caminho do nível 2 para o 3"
  end

  test "estilo favorito: o que a pessoa mais treina; empate fica com o mais recente" do
    assert_nil stats.favorite_style
    train(@setup, at: 3.days.ago)
    assert_nil stats.favorite_style, "tarefa de base não conta estilo"

    train(@shove_it, at: 2.days.ago)
    train(@no_comply, at: 1.day.ago)
    assert_equal "old_school", stats.favorite_style

    train(@shove_it, at: Time.current)
    assert_equal "street", stats.favorite_style
  end
end
