require "test_helper"

class StreakTest < ActiveSupport::TestCase
  setup do
    travel_to Time.zone.parse("2026-10-13 15:00 -03:00") # terça
    @user = User.create!(time_zone: "America/Sao_Paulo")
  end

  def today = Date.new(2026, 10, 13)
  def session_on(date) = @user.skate_sessions.create!(skated_on: date)
  def streak = Streak.new(@user)

  def justify(on:, status: :pending)
    @user.streak_justifications.create!(reason: "Torci o tornozelo.", status: status,
                                        created_at: on.in_time_zone("America/Sao_Paulo").change(hour: 12))
  end

  test "sem sessão ainda, a ofensiva começa do zero e não dá para justificar" do
    assert_equal :none, streak.state
    assert_equal 0, streak.count
    assert_not streak.can_justify?
  end

  test "cada sessão soma 1, no máximo uma por dia, e não precisa ser todo dia" do
    session_on(today - 12)
    session_on(today - 6)
    session_on(today - 6)
    session_on(today)

    assert_equal :active, streak.state
    assert_equal 3, streak.count
    assert_equal today + 7, streak.deadline
    assert_equal 7, streak.days_left
  end

  test "só perde depois de mais de 7 dias sem sessão; o recorde fica" do
    session_on(today - 9)
    session_on(today - 7)
    assert_equal 2, streak.count, "7 dias sem sessão ainda vale"

    travel 1.day
    assert_equal :lost, streak.state
    assert_equal 0, streak.count
    assert_equal 2, streak.best

    session_on(today + 1)
    assert_equal 1, streak.count, "a próxima sessão começa uma ofensiva nova"
  end

  test "justificativa esperando o mentor segura a ofensiva; aprovada, a parada não conta" do
    session_on(today - 20)
    session_on(today - 15)
    justification = justify(on: today - 10)

    assert_equal :frozen, streak.state
    assert_equal 2, streak.count
    assert_not streak.can_justify?, "uma justificativa por parada"

    justification.update!(status: :approved)
    assert_equal :paused, streak.state

    session_on(today)
    assert_equal :active, streak.state
    assert_equal 3, streak.count, "a parada aprovada não quebrou a sequência"
  end

  test "justificativa recusada: a parada conta e a ofensiva se perde" do
    session_on(today - 15)
    justify(on: today - 9, status: :rejected)

    assert_equal :lost, streak.state
    assert_equal 0, streak.count

    session_on(today)
    assert_equal 1, streak.count
  end
end
