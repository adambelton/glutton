import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["dialog"]

  dialogTargetConnected(dialog) {
    dialog.showModal()
  }

  close() {
    if (this.hasDialogTarget) this.dialogTarget.close()
  }
}
