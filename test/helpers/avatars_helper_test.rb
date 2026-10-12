require "test_helper"

class AvatarsHelperTest < ActionView::TestCase
  test "o lado direito do corpo é o esquerdo espelhado na linha do meio" do
    assert_equal "M140 104 C146 116 149.5 132 150 148 L141.5 197 Z", avatar_mirror("M60 104 C54 116 50.5 132 50 148 L58.5 197 Z")
  end

  test "os dois lados vão num caminho só" do
    assert_equal "M90 10 L80 20 M110 10 L120 20", avatar_both("M90 10 L80 20")
  end
end
