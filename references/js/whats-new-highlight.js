// What's New highlighter without a framework, for server-rendered pages.
// Include once per page (in the layout). Same behavior as useWhatsNewHighlight:
// find [data-whats-new="<key>"] for ?whats_new=<key>, scroll to it, pulse it,
// then drop the param from the URL. With Turbo, also run it on "turbo:load".
;(function () {
  var PARAM = "whats_new"
  var CLASS = "whats-new-highlight"
  var HIGHLIGHT_MS = 6000
  var WAIT_MS = 8000

  function highlight(key) {
    var targets = Array.prototype.filter.call(
      document.querySelectorAll('[data-whats-new="' + key + '"]'),
      function (el) { return el.getClientRects().length > 0 }
    )
    if (targets.length === 0) return false
    targets.forEach(function (el) { el.classList.add(CLASS) })
    targets[0].scrollIntoView({ behavior: "smooth", block: "center" })
    setTimeout(function () { targets.forEach(function (el) { el.classList.remove(CLASS) }) }, HIGHLIGHT_MS)
    return true
  }

  function stripParam() {
    var url = new URL(window.location.href)
    url.searchParams.delete(PARAM)
    window.history.replaceState(window.history.state, "", url)
  }

  function run() {
    var key = new URLSearchParams(window.location.search).get(PARAM)
    if (!key || !/^[a-z0-9-]+$/.test(key)) return
    if (highlight(key)) return stripParam()

    var observer = new MutationObserver(function () {
      if (!highlight(key)) return
      done()
    })
    var timeout = setTimeout(done, WAIT_MS)
    function done() {
      observer.disconnect()
      clearTimeout(timeout)
      stripParam()
    }
    observer.observe(document.body, { childList: true, subtree: true })
  }

  if (document.readyState === "loading") document.addEventListener("DOMContentLoaded", run)
  else run()
  document.addEventListener("turbo:load", run)
})()
