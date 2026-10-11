require "test_helper"

class MeetupTest < ActiveSupport::TestCase
  setup do
    travel_to Time.zone.parse("2026-10-11 13:00 -03:00") # domingo, 13h em Brasília
    @user = User.create!(time_zone: "America/Sao_Paulo")
  end

  def meetup(**attrs)
    @user.meetups.new({ place_name: "Pista do parque", latitude: -15.7939, longitude: -47.8828,
                        day: Date.new(2026, 10, 11), start_time: "16:00", end_time: "18:00" }.merge(attrs))
  end

  test "o dia e os horários valem no fuso de quem marca" do
    scheduled = meetup
    assert scheduled.save, scheduled.errors.full_messages.to_sentence

    assert_equal Time.utc(2026, 10, 11, 19), scheduled.starts_at
    assert_equal Time.utc(2026, 10, 11, 21), scheduled.ends_at
    assert_equal "Dom, 11/10 · 16h às 18h", scheduled.schedule_label
    assert_equal "Dom, 11/10 · 16h30 às 18h", meetup(start_time: "16:30").tap(&:valid?).schedule_label
  end

  test "recusa lugar vazio, horário que passou, fim antes do começo, mais de 12h e mais de 60 dias" do
    {
      { place_name: " " }                        => "Diga onde vai ser o rolê.",
      { latitude: nil }                          => "Toque no mapa ou escolha um pico para marcar o lugar.",
      { start_time: "09:00", end_time: "11:00" } => "Esse horário já passou. Escolha um que ainda vai acontecer.",
      { start_time: "18:00", end_time: "16:00" } => "O horário de fim precisa ser depois do começo.",
      { start_time: "00:00", end_time: "23:00" } => "Um rolê pode durar até 12 horas.",
      { day: Date.new(2026, 12, 25) }            => "Marque rolês para os próximos 60 dias.",
      { start_time: "25:99" }                    => "Escolha o dia e os horários do rolê.",
      { note: "a" * 141 }                        => "O recado pode ter até 140 letras."
    }.each do |attrs, message|
      scheduled = meetup(**attrs)
      assert_not scheduled.valid?, "deveria recusar #{attrs}"
      assert_includes scheduled.errors.full_messages, message
    end
  end

  test "um rolê que já começou e ainda não acabou vale" do
    assert meetup(start_time: "12:00", end_time: "15:00").save
    assert @user.meetups.last.happening_now?
  end

  test "no máximo 5 rolês marcados ao mesmo tempo" do
    5.times { |hour| assert meetup(start_time: "#{14 + hour}:00", end_time: "#{15 + hour}:00").save }

    sixth = meetup(start_time: "20:00", end_time: "21:00")
    assert_not sixth.save
    assert_includes sixth.errors.full_messages, "Você já tem 5 rolês marcados. Cancele um para marcar outro."
  end

  test "cada rolê tem um link secreto e some quando acaba" do
    scheduled = meetup.tap(&:save!)
    assert_equal 24, scheduled.share_token.length
    assert_equal "https://www.google.com/maps/search/?api=1&query=-15.7939,-47.8828", scheduled.google_maps_url

    travel 6.hours
    assert_equal 1, Meetup.purge_expired!
    assert_not Meetup.exists?(scheduled.id)
  end
end
