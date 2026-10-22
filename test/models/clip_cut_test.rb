require "test_helper"

# O trecho do vídeo que é guardado (barra de corte da tela Gravar): TrainingSession.clip_cut.
class ClipCutTest < ActiveSupport::TestCase
  def cut(...) = TrainingSession.clip_cut(...)

  test "fica o trecho escolhido" do
    assert_equal 5.5..15.25, cut("5.5", "15.25", "40")
    assert_equal 0.0..8.4, cut("0", "8.4", "8.4")
  end

  test "nunca passa de 20 segundos" do
    assert_equal 2.0..22.0, cut("2", "39", "40")
    assert_equal 0.0..20.0, cut(nil, nil, "40"), "sem trecho, os primeiros 20s"
    assert_equal 0.0..20.0, cut(nil, nil), "nem a duração conhecida"
  end

  test "vídeo curto: o trecho termina no fim do vídeo" do
    assert_equal 0.0..6.0, cut(nil, nil, "6")
    assert_equal 1.0..6.0, cut("1", "9", "6")
  end

  test "valores fora das regras viram o mais próximo válido" do
    assert_equal 0.0..20.0, cut("-3", "abc", "40")
    assert_equal 0.0..20.0, cut("Infinity", "NaN", "40")
    assert_equal 12.0..32.0, cut("12", "4", "40"), "fim antes do começo: 20s a partir do começo"
    assert_equal 0.0..10.0, cut("50", "60", "10"), "começo depois do fim do vídeo: volta ao início"
    assert_equal 3.0..23.0, cut("3", nil, "0"), "duração zero é tratada como desconhecida"
  end
end
