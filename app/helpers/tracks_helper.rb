module TracksHelper
  # Tamanho original de skate_overworld_map.jpg, em pixels.
  MAP_SIZE = [ 1376, 768 ].freeze

  # Centro de cada bolinha da linha azul do mapa, em pixels da imagem original,
  # na ordem da trilha: começa na bolinha verde (START HOME) e termina na
  # bandeira quadriculada. Ao trocar a imagem do mapa, meça de novo os pontos.
  MAP_POINTS = [
    [ 168, 648 ], [ 255, 598 ], [ 233, 495 ], [ 196, 406 ], [ 283, 357 ],
    [ 395, 307 ], [ 513, 290 ], [ 563, 425 ], [ 660, 497 ], [ 753, 545 ],
    [ 955, 472 ], [ 1012, 383 ], [ 1110, 323 ], [ 1215, 258 ], [ 1310, 240 ]
  ].freeze

  def map_aspect_ratio = MAP_SIZE.join(" / ")

  # Posição do nó em % da imagem, para acompanhar o desenho em qualquer tela.
  # Se a trilha tiver mais nós que pontos, os excedentes repetem o último ponto:
  # adicione pontos acima.
  def map_node_position(index)
    x, y = MAP_POINTS[index] || MAP_POINTS.last
    width, height = MAP_SIZE
    "left: #{(x * 100.0 / width).round(2)}%; top: #{(y * 100.0 / height).round(2)}%;"
  end
end
