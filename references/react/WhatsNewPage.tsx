import { useEffect, useState } from "react"
import { Link } from "@inertiajs/react"
// Wrap in the app's own layout component, the one that calls useWhatsNewHighlight.

export interface WhatsNewScreenshot {
  /** Served by whats_new#screenshot, behind the entry's own check. */
  src: string
  alt: string
  width: number | null
  height: number | null
  /** Taller than wide: shown narrow rather than stretched. */
  phone: boolean
}

export interface WhatsNewEntry {
  date: string
  title: string
  body: string
  /** The feature's page, with ?whats_new=<key> already on it. */
  href: string
  screenshots: WhatsNewScreenshot[]
  /** Empty unless the reader may open the repo. */
  prs: { number: number; url: string }[]
}

function formatDate(date: string): string {
  const parsed = new Date(`${date}T12:00:00`)
  if (Number.isNaN(parsed.getTime())) return date
  return parsed.toLocaleDateString("en-US", { month: "short", day: "numeric", year: "numeric" })
}

/** Newest date first, in the server's order. */
function byDate(entries: WhatsNewEntry[]): [string, WhatsNewEntry[]][] {
  const groups = new Map<string, WhatsNewEntry[]>()
  for (const entry of entries) groups.set(entry.date, [...(groups.get(entry.date) ?? []), entry])
  return [...groups]
}

/**
 * An entry's screenshots in a row: desktop shots share the width, phone shots
 * sit at phone size beside them. Click one to see it full size.
 */
function Screenshots({ shots, onOpen }: { shots: WhatsNewScreenshot[]; onOpen: (shot: WhatsNewScreenshot) => void }) {
  return (
    <div className="mt-4 flex flex-wrap items-start gap-3 sm:flex-nowrap">
      {shots.map((shot) => (
        <button
          key={shot.src}
          type="button"
          onClick={() => onOpen(shot)}
          aria-label={`Enlarge: ${shot.alt}`}
          className={`block overflow-hidden rounded-md border border-gray-200 bg-gray-100 ${
            shot.phone ? "w-[calc(50%-0.375rem)] max-w-48 shrink-0 sm:w-48" : "w-full min-w-0 sm:max-w-3xl sm:flex-1"
          }`}
          // A tight crop stays its own size rather than stretching to the row.
          style={!shot.phone && shot.width ? { maxWidth: shot.width } : undefined}
        >
          <img
            src={shot.src}
            alt={shot.alt}
            width={shot.width ?? undefined}
            height={shot.height ?? undefined}
            loading="lazy"
            decoding="async"
            className="block h-auto w-full"
          />
        </button>
      ))}
    </div>
  )
}

function Lightbox({ shot, onClose }: { shot: WhatsNewScreenshot; onClose: () => void }) {
  useEffect(() => {
    const onKey = (event: KeyboardEvent) => event.key === "Escape" && onClose()
    window.addEventListener("keydown", onKey)
    return () => window.removeEventListener("keydown", onKey)
  }, [onClose])

  return (
    <div
      role="dialog"
      aria-modal="true"
      aria-label={shot.alt}
      onClick={onClose}
      className="fixed inset-0 z-50 flex flex-col items-center justify-center gap-3 bg-black/80 p-4"
    >
      <img src={shot.src} alt={shot.alt} className="max-h-[85vh] max-w-full rounded-md object-contain shadow-2xl" />
      <p className="max-w-3xl rounded-md bg-white px-3 py-1.5 text-center text-sm text-gray-700">{shot.alt}</p>
    </div>
  )
}

export default function WhatsNewPage({ entries }: { entries: WhatsNewEntry[] }) {
  const [open, setOpen] = useState<WhatsNewScreenshot | null>(null)

  return (
    <div className="mx-auto w-full max-w-5xl px-4 py-8 sm:px-6">
      <h1 className="text-2xl font-semibold text-gray-900">What's New</h1>

      {entries.length === 0 ? (
        <p className="mt-6 text-sm text-gray-600">Nothing here yet.</p>
      ) : (
        byDate(entries).map(([date, group]) => (
          <section key={date} className="mt-8">
            <h2 className="text-xs font-semibold uppercase tracking-wide text-gray-500">{formatDate(date)}</h2>
            <ul className="mt-3 space-y-4">
              {group.map((entry) => (
                <li key={entry.title} className="rounded-lg border border-gray-200 bg-white p-4 sm:p-5">
                  <h3 className="font-semibold text-gray-900">{entry.title}</h3>
                  <p className="mt-1 max-w-3xl text-sm leading-6 text-gray-700">{entry.body}</p>
                  <div className="mt-2 flex flex-wrap items-baseline gap-x-3 gap-y-1">
                    <Link href={entry.href} className="text-sm font-medium text-amber-700 hover:text-amber-800">
                      Show me
                    </Link>
                    {entry.prs.map((pr) => (
                      <a key={pr.number} href={pr.url} target="_blank" rel="noreferrer" className="text-xs text-gray-500 hover:text-gray-700">
                        PR #{pr.number}
                      </a>
                    ))}
                  </div>
                  {entry.screenshots.length > 0 && <Screenshots shots={entry.screenshots} onOpen={setOpen} />}
                </li>
              ))}
            </ul>
          </section>
        ))
      )}
      {open && <Lightbox shot={open} onClose={() => setOpen(null)} />}
    </div>
  )
}
