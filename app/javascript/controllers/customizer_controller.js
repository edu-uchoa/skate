import { Controller } from "@hotwired/stimulus"

// Prévia ao vivo do editor de avatar e de skate do Perfil.
//
// O desenho já vem com todas as opções (customizer_layer): ao escolher uma, mostra
// as camadas daquela parte com a opção certa (data-part / data-option), troca as
// cores (variáveis CSS em data-vars) e, se for o caso, um atributo do desenho
// (data-attr, ex.: a base do avatar ou o capacete, que esconde o cabelo de cima).
export default class extends Controller {
  static targets = ["preview"]

  update({ target: input }) {
    const part = input.name?.match(/\[(\w+)\]$/)?.[1]
    if (!part) return

    const value = input.type === "checkbox" ? String(input.checked) : input.value
    this.previewTarget.querySelectorAll(`[data-part="${part}"]`).forEach((layer) => {
      layer.style.display = layer.dataset.option === value ? "" : "none"
    })

    if (input.dataset.attr) this.previewTarget.dataset[input.dataset.attr] = value
    if (input.dataset.vars) {
      Object.entries(JSON.parse(input.dataset.vars)).forEach(([name, color]) => {
        this.previewTarget.style.setProperty(name, color)
      })
    }
  }
}
