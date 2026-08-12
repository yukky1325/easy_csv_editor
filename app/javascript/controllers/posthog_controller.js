import { Controller } from "@hotwired/stimulus"
import { initPosthog, capturePageview } from "analytics/posthog"

export default class extends Controller {
  static values = {
    enabled: Boolean,
    apiKey: String,
    apiHost: String,
    distinctId: String
  }

  connect() {
    if (!this.enabledValue) return

    initPosthog({
      apiKey: this.apiKeyValue,
      apiHost: this.apiHostValue,
      distinctId: this.distinctIdValue
    })

    this.onPageLoad = this.onPageLoad.bind(this)
    document.addEventListener("turbo:load", this.onPageLoad)
    this.onPageLoad()
  }

  disconnect() {
    document.removeEventListener("turbo:load", this.onPageLoad)
  }

  onPageLoad() {
    capturePageview()
  }
}
