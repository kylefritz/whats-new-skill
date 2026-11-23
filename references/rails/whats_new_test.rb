require "test_helper"

# The checks that keep What's New honest: a bad entry fails CI, not the page.
class WhatsNewTest < ActiveSupport::TestCase
  # Where the app's components live, so "every highlight is tagged" searches them.
  FRONTEND_GLOB = "app/frontend/**/*.{ts,tsx,js,jsx}".freeze   # add app/views/**/*.erb for server-rendered pages

  LINK = { href: "/reports", highlight: "csv-export" }.freeze

  ENTRIES = [
    { date: "2026-11-03", title: "For admins", body: "b", audience: "admins" },
    { date: "2026-11-02", title: "For editors", body: "b", audience: "editors" },
    { date: "2026-11-01", title: "For everyone", body: "b", audience: "everyone" }
  ].map { |attrs| WhatsNew::Entry.from(attrs.merge(LINK)) }.freeze

  def entry(**attrs)
    WhatsNew::Entry.from({ date: "2026-11-01", title: "t", body: "b", audience: "everyone" }.merge(LINK).merge(attrs))
  end

  def titles(role) = WhatsNew.visible_to(role: role, entries: ENTRIES).map(&:title)

  # Audience

  test "each role sees only its audiences" do
    assert_equal [ "For everyone" ], titles("member")
    assert_equal [ "For editors", "For everyone" ], titles("editor")
    assert_equal [ "For admins", "For editors", "For everyone" ], titles("admin")
  end

  test "an unknown role reads everyone's entries only" do
    assert_equal [ "For everyone" ], titles(nil)
  end

  test "an unknown or missing audience is refused rather than shown to everyone" do
    assert_raises(ArgumentError) { entry(audience: "managers") }
    assert_raises(ArgumentError) { entry(audience: nil) }
  end

  test "the latest date is the newest one this reader can see" do
    assert_equal "2026-11-01", WhatsNew.latest_date(role: "member", entries: ENTRIES)
    assert_equal "2026-11-03", WhatsNew.latest_date(role: "admin", entries: ENTRIES)
  end

  # Links

  test "an entry needs a link and something to highlight" do
    assert_raises(ArgumentError) { entry(href: nil) }
    assert_raises(ArgumentError) { entry(highlight: " ") }
  end

  test "the link carries the highlight key, keeping any query" do
    assert_equal "/reports?whats_new=csv-export", entry.link
    assert_equal "/reports?view=table&whats_new=csv-export", entry(href: "/reports?view=table").link
  end

  test "an example replaces the href and keeps the key" do
    assert_equal "/invoices/7?whats_new=csv-export", entry.link("/invoices/7")
  end

  # The file itself

  test "every entry in the file loads, newest first" do
    dates = WhatsNew.all.map(&:date)
    assert_not_empty dates
    assert_equal dates.sort.reverse, dates
  end

  test "within a date the file's order stands" do
    entries = [ entry(title: "Older"), entry(date: "2026-11-02", title: "Lead"), entry(date: "2026-11-02", title: "Second") ]
    assert_equal %w[Lead Second Older], WhatsNew.newest_first(entries).map(&:title)
  end

  test "every entry's link is a real route" do
    WhatsNew.all.map(&:href).each do |href|
      assert Rails.application.routes.recognize_path(href), "#{href} isn't a route"
    end
  end

  # The highlighter ignores any other shape, so a key like csv_export would
  # land and silently light up nothing.
  test "every highlight is lowercase with hyphens" do
    WhatsNew.all.each { |e| assert_match WhatsNew::KEY_FORMAT, e.highlight, e.title }
  end

  # A key nobody renders is a link that lands and highlights nothing.
  test "every highlight is tagged somewhere in the frontend" do
    source = Rails.root.glob(FRONTEND_GLOB).map(&:read).join("\n")
    WhatsNew.all.map(&:highlight).uniq.each do |key|
      assert_match(/data-whats-new=(\{[^}\n]*)?["']#{key}["']/, source, "no data-whats-new=\"#{key}\" in #{FRONTEND_GLOB}")
    end
  end

  test "entries use straight quotes and no em dashes" do
    WhatsNew.all.each { |e| assert_no_match(/[‘’“”—]/, "#{e.title} #{e.body}", e.title) }
  end

  # Screenshots

  test "a screenshot needs a webp name and alt text" do
    assert_raises(ArgumentError) { entry(screenshots: [ { file: "a.png", alt: "a" } ]) }
    assert_raises(ArgumentError) { entry(screenshots: [ { file: "a.webp" } ]) }
  end

  test "entry keys are unique, so each owns one screenshots folder" do
    keys = WhatsNew.all.map(&:key)
    assert_equal keys.uniq, keys
  end

  test "every listed screenshot exists, is a WebP, and isn't huge" do
    WhatsNew.all.each do |e|
      e.screenshots.each do |s|
        path = WhatsNew::SCREENSHOTS.join(e.key, s.file)
        assert path.exist?, "#{e.title}: #{path.relative_path_from(Rails.root)} is missing"
        assert s.width && s.height, "#{e.title}: #{s.file} isn't a WebP"
        assert s.width <= 1600, "#{e.title}: #{s.file} is #{s.width}px wide; resize to 1600 or less"
        assert path.size < 250.kilobytes, "#{e.title}: #{s.file} is #{path.size / 1024}KB"
      end
    end
  end

  # Both ways: nothing listed is missing, and nothing on disk goes unlisted (an
  # unlisted file is never served, but it still ships and still needs its
  # privacy check).
  test "every screenshots folder belongs to an entry that lists all of it" do
    skip "no screenshots yet" unless WhatsNew::SCREENSHOTS.exist?

    by_key = WhatsNew.all.index_by(&:key)
    WhatsNew::SCREENSHOTS.children.select(&:directory?).each do |dir|
      e = by_key[dir.basename.to_s]
      assert e, "#{dir.basename} matches no entry's title"
      assert_equal dir.children.map { |f| f.basename.to_s }.sort, e.screenshots.map(&:file).sort,
                   "#{e.title} doesn't list every file in its folder"
    end
  end

  # Add one line per gated area of the app, so an entry can't announce a page
  # to people the page itself refuses:
  #   GATES = { "/admin" => "admins", "/billing" => "editors" }
  GATES = { "/admin" => "admins" }.freeze

  test "entries for gated pages are no wider than the page" do
    WhatsNew.all.each do |e|
      gate = GATES.find { |prefix, _| e.href.start_with?(prefix) }&.last or next
      assert_equal gate, e.audience, "#{e.title} links to #{e.href}"
    end
  end
end
