import posthog from "posthog-js"

let initialized = false

export function initPosthog({ apiKey, apiHost, distinctId }) {
  if (initialized || !apiKey) return

  posthog.init(apiKey, {
    api_host: apiHost,
    person_profiles: "identified_only",
    capture_pageview: false,
    autocapture: false,
    persistence: "localStorage+cookie"
  })

  if (distinctId) {
    posthog.identify(distinctId)
  }

  initialized = true
}

export function capturePageview() {
  if (!initialized) return

  posthog.capture("$pageview", {
    $current_url: window.location.href,
    $pathname: window.location.pathname
  })
}
