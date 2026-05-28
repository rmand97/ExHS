const COOKIE_NAME = "exhs_consent"
const COOKIE_DAYS = 365

function getConsent() {
  const match = document.cookie.match(new RegExp(`${COOKIE_NAME}=([^;]+)`))
  return match ? match[1] : null
}

function setConsent(value) {
  const expires = new Date(Date.now() + COOKIE_DAYS * 864e5).toUTCString()
  document.cookie = `${COOKIE_NAME}=${value}; expires=${expires}; path=/; SameSite=Lax`
}

function hideBanner() {
  const banner = document.getElementById("cookie-consent")
  if (banner) banner.hidden = true
}

function showBanner() {
  const banner = document.getElementById("cookie-consent")
  if (banner) banner.hidden = false
}

export function initCookieConsent() {
  if (getConsent()) return

  showBanner()

  document.addEventListener("click", (e) => {
    if (e.target.closest("[data-consent-accept]")) {
      setConsent("all")
      hideBanner()
    } else if (e.target.closest("[data-consent-reject]")) {
      setConsent("essential")
      hideBanner()
    }
  })
}

export function hasAnalyticsConsent() {
  return getConsent() === "all"
}
