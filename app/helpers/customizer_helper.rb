module CustomizerHelper
  # Uma camada do desenho do avatar ou do skate (um corte de cabelo, um tênis, um
  # tipo de skate...). No editor, todas as opções vão para a página e só a escolhida
  # aparece (customizer_controller.js troca na hora); fora dele, só vai a escolhida.
  def customizer_layer(model, part, option, editable, &block)
    selected = model[part].to_s == option.to_s
    return unless selected || editable

    tag.g(data: { part: part, option: option }, style: ("display: none" unless selected), &block)
  end
end
