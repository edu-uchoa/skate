module AvatarsHelper
  # Espelha um caminho SVG na linha do meio do avatar (x = 100): o lado direito do
  # corpo (braço, perna, olho, tênis) é desenhado uma vez só, no lado esquerdo. Vale
  # para caminhos com comandos absolutos de pares x,y (M, L, C, Q, Z).
  def avatar_mirror(path, axis = 100)
    index = 0
    path.gsub(/[A-Za-z]|-?\d*\.?\d+/) do |token|
      if token.match?(/\A[A-Za-z]\z/)
        index = 0
        token
      else
        value = index.even? ? 2 * axis - token.to_f : token.to_f
        index += 1
        value.round(2).to_s.delete_suffix(".0")
      end
    end
  end

  # Os dois lados de uma vez: o caminho do lado esquerdo seguido do espelhado.
  def avatar_both(path) = "#{path} #{avatar_mirror(path)}"
end
