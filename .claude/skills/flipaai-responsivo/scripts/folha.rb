# Junta vários prints numa folha só (metade do tamanho, 7 por linha) para comparar telas.
#
#   bundle exec ruby .claude/skills/flipaai-responsivo/scripts/folha.rb <saida.png> <print1.png> <print2.png> ...
require "vips"

saida, *prints = ARGV
abort "Use: folha.rb saida.png print1.png print2.png ..." if prints.empty?

imagens = prints.map do |arquivo|
  img = Vips::Image.new_from_file(arquivo).resize(0.5)
  img.bands > 3 ? img.extract_band(0, n: 3) : img
end
Vips::Image.arrayjoin(imagens, across: 7, shim: 6, background: [ 255, 0, 255 ]).write_to_file(saida)
puts "folha salva em #{saida}"
