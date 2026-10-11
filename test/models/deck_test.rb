require "test_helper"

class DeckTest < ActiveSupport::TestCase
  test "tem os quatro tipos de skate, cada um com a sua estampa padrão" do
    assert_equal %w[street new_school bowl old_school], Deck::TYPES.map(&:key)
    assert Deck::TYPES.all? { |type| type.print.present? && type.outline.start_with?("M") }
    assert_equal SkateStyle::NAMES.keys.sort, Deck::TYPES.map(&:key).sort, "os mesmos estilos do perfil"
  end

  test "guarda só opções da lista; o resto volta para o padrão" do
    deck = Deck.new("type" => "bowl", "wheels" => "azul", "trucks" => "titanio")

    assert_equal "bowl", deck.type.key
    assert_equal "azul", deck[:wheels]
    assert_equal "prata", deck[:trucks]
    assert_equal "--deck-wheels: #3b8cff; --deck-trucks: #b8bcc4;", deck.css_variables
    assert_equal "street", Deck.new(nil).type.key
  end
end
