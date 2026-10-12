require "test_helper"

class AvatarTest < ActiveSupport::TestCase
  test "sem escolhas, o avatar já vem pronto e de capacete" do
    look = Avatar.new({})

    assert_equal "feminino", look[:base]
    assert_equal "capacete-amarelo", look[:head]
    assert_equal false, look[:vitiligo]
    assert_match "--av-skin: #c98c62;", look.css_variables
  end

  test "guarda só opções da lista; o resto volta para o padrão" do
    look = Avatar.new("base" => "masculino", "hair" => "black-power", "skin" => "6", "vitiligo" => "true",
                      "head" => "coroa-de-ouro", "top_color" => "<script>")

    assert_equal "masculino", look[:base]
    assert_equal "black-power", look[:hair]
    assert look[:vitiligo]
    assert_equal "capacete-amarelo", look[:head]
    assert_equal Avatar::DEFAULTS[:top_color], look[:top_color]
    assert_match "--av-skin: #4f2f1c; --av-skin-shade: #3d2415;", look.css_variables
  end

  test "opções do avatar antigo que saíram voltam para o padrão" do
    look = Avatar.new("hair" => "moicano", "top" => "jaqueta", "shoes" => "slip-on-xadrez", "head" => "aba-reta")

    %i[hair top shoes head].each { |part| assert_equal Avatar::DEFAULTS[part], look[part], part }
  end

  test "as roupas são as dos jogos de skate de hoje, largas e sem marca" do
    assert_equal %w[moletom-capuz moletom-caveira camiseta-larga camiseta-estampa xadrez], Avatar::OPTIONS[:top].map(&:key)
    assert_includes Avatar::OPTIONS[:bottom].map(&:key), "bermuda-preta"
    assert_includes Avatar::OPTIONS[:head].map(&:key), "bone-para-tras"
  end

  test "todas as partes têm opções e um padrão que existe na lista" do
    Avatar::DEFAULTS.except(:vitiligo).each do |part, default|
      assert_includes Avatar::OPTIONS.fetch(part).map(&:key), default, part
    end
    assert_equal Avatar::DEFAULTS.keys - [ :vitiligo ], Avatar::GROUPS.keys
  end
end
