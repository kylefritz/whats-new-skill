import { useEffect } from "react"

// A What's New link lands with ?whats_new=<key>. The thing it announces is
// tagged data-whats-new="<key>" in the page. Scroll to it and pulse it, then
// take the param off the URL so a reload or a shared link doesn't replay it.
//
// Call once in the shared layout: useWhatsNewHighlight(pageUrl), where pageUrl
// changes on every client-side navigation (Inertia's usePage().url, the router
// location, etc).

export const HIGHLIGHT_PARAM = "whats_new"
export const HIGHLIGHT_CLASS = "whats-new-highlight"
const HIGHLIGHT_MS = 6000
// Some targets render after the page does (a panel that fetches its own data).
const WAIT_FOR_TARGET_MS = 8000
const KEY_FORMAT = /^[a-z0-9-]+$/

function isVisible(element: Element): boolean {
  return element.getClientRects().length > 0
}

/** Pulses every visible element with this key. False if none is on the page yet. */
export function highlightTargets(key: string, root: ParentNode = document, hasLayout: (el: Element) => boolean = isVisible): boolean {
  const targets = [...root.querySelectorAll(`[data-whats-new="${key}"]`)].filter(hasLayout)
  if (targets.length === 0) return false

  targets.forEach((target) => target.classList.add(HIGHLIGHT_CLASS))
  targets[0].scrollIntoView?.({ behavior: "smooth", block: "center" })
  window.setTimeout(() => targets.forEach((target) => target.classList.remove(HIGHLIGHT_CLASS)), HIGHLIGHT_MS)
  return true
}

function stripParam() {
  const url = new URL(window.location.href)
  url.searchParams.delete(HIGHLIGHT_PARAM)
  window.history.replaceState(window.history.state, "", url)
}

export function useWhatsNewHighlight(pageUrl: string) {
  useEffect(() => {
    const key = new URLSearchParams(window.location.search).get(HIGHLIGHT_PARAM)
    // The key goes into a selector, so only the safe shape is accepted.
    if (!key || !KEY_FORMAT.test(key)) return

    if (highlightTargets(key)) {
      stripParam()
      return
    }

    // Not on the page yet: watch for it. The param stays until this settles, so
    // a re-run of the effect can keep waiting.
    const observer = new MutationObserver(() => {
      if (!highlightTargets(key)) return
      stop()
      stripParam()
    })
    const timeout = window.setTimeout(() => {
      stop()
      stripParam()
    }, WAIT_FOR_TARGET_MS)
    function stop() {
      observer.disconnect()
      window.clearTimeout(timeout)
    }
    observer.observe(document.body, { childList: true, subtree: true })
    return stop
  }, [pageUrl])
}
