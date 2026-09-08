import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["input", "dropzone", "filename", "prompt"]

  highlight(event) {
    event.preventDefault()
    this.dropzoneTarget.classList.add("is-dragover")
  }

  unhighlight(event) {
    event.preventDefault()
    if (this.dropzoneTarget.contains(event.relatedTarget)) return

    this.dropzoneTarget.classList.remove("is-dragover")
  }

  drop(event) {
    event.preventDefault()
    this.dropzoneTarget.classList.remove("is-dragover")

    const file = event.dataTransfer?.files?.[0]
    if (!file) return

    this.assignFile(file)
  }

  change() {
    this.updateLabel(this.inputTarget.files[0])
  }

  assignFile(file) {
    const transfer = new DataTransfer()
    transfer.items.add(file)
    this.inputTarget.files = transfer.files
    this.updateLabel(file)
  }

  updateLabel(file) {
    const hasFile = Boolean(file)

    this.promptTarget.hidden = hasFile
    this.filenameTarget.hidden = !hasFile
    this.filenameTarget.textContent = hasFile ? file.name : ""
    this.dropzoneTarget.classList.toggle("has-file", hasFile)
  }
}
