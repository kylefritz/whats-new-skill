# frozen_string_literal: true

# The What's New page: one entry per user-visible feature, read from
# config/whats_new.yml so an entry ships in the same PR as its feature.
#
# An entry describes a feature, so it has to be as private as the feature.
# Every entry names its audience; a missing or unknown one raises rather than
# defaulting open, and filtering happens on the server so a hidden entry never
# reaches the browser.
#
# Every entry links to the feature and names what to highlight when you land:
# href is the page (or the fallback when `example` resolves to nothing), and
# highlight is a data-whats-new key on that page.
#
# Screenshots live in config/whats_new/screenshots/<entry key>/, outside
# public/, and WhatsNewController#screenshot serves them behind the entry's own
# check, so an image can't reach someone the entry is hidden from.
class WhatsNew
  PATH = Rails.root.join("config/whats_new.yml")
  SCREENSHOTS = Rails.root.join("config/whats_new/screenshots")
  # Set to the repo's URL to show PR links (to admins only; see the controller).
  REPO_URL = nil

  # Which audiences each role may read. Edit to the app's real roles: the keys
  # are what `role_for(user)` in the controller returns, the values are the
  # audiences an entry may name. Signed-in users with no listed role read
  # "everyone" only.
  AUDIENCES_BY_ROLE = {
    "admin" => %w[everyone editors admins],
    "editor" => %w[everyone editors],
    "member" => %w[everyone]
  }.freeze
  AUDIENCES = AUDIENCES_BY_ROLE.values.flatten.uniq.freeze
  KEY_FORMAT = /\A[a-z0-9-]+\z/

  Screenshot = Data.define(:file, :alt, :width, :height, :path, :version) do
    def self.from(attrs, key:)
      attrs = attrs.to_h.transform_keys(&:to_sym)
      file = attrs[:file].to_s
      unless file.match?(/\A[a-z0-9-]+\.webp\z/)
        raise ArgumentError, "#{key}: a screenshot file looks like name.webp, got #{file.inspect}"
      end
      raise ArgumentError, "#{key}/#{file}: alt is required" if attrs[:alt].blank?

      # Built once from the file, never from a request.
      path = WhatsNew::SCREENSHOTS.join(key, file)
      width, height = WhatsNew.webp_size(path)
      # In the URL, so a replaced image isn't stuck behind a cached copy.
      version = path.exist? ? Digest::SHA256.file(path).hexdigest.first(10) : "0"
      new(file: file, alt: attrs[:alt], width: width, height: height, path: path, version: version)
    end

    def bytes = File.binread(path)

    # Taller than wide: the page shows it narrow rather than stretched.
    def phone? = width.present? && height.present? && height > width
  end

  Entry = Data.define(:date, :title, :body, :audience, :href, :highlight, :example, :prs, :key, :screenshots) do
    def self.from(attrs)
      attrs = attrs.to_h.transform_keys(&:to_sym)
      label = attrs[:title].inspect
      unless WhatsNew::AUDIENCES.include?(attrs[:audience])
        raise ArgumentError, "#{label}: audience must be one of #{WhatsNew::AUDIENCES.join(", ")}, got #{attrs[:audience].inspect}"
      end
      %i[href highlight].each do |field|
        raise ArgumentError, "#{label}: #{field} is required" if attrs[field].blank?
      end

      # The screenshots folder's name: the title, apostrophes dropped.
      key = attrs.fetch(:title).to_s.delete("'").parameterize
      screenshots = Array(attrs[:screenshots]).map { |shot| WhatsNew::Screenshot.from(shot, key: key) }
      new(date: attrs.fetch(:date).to_s, title: attrs.fetch(:title), body: attrs.fetch(:body),
          audience: attrs[:audience], href: attrs[:href], highlight: attrs[:highlight],
          example: attrs[:example], prs: Array(attrs[:prs]), key: key, screenshots: screenshots)
    end

    def visible_to?(role:)
      WhatsNew::AUDIENCES_BY_ROLE.fetch(role.to_s, %w[everyone]).include?(audience)
    end

    def screenshot(file) = screenshots.find { |shot| shot.file == file }

    # The link carries the key the page highlights, whichever page it lands on.
    def link(example_href = nil)
      target = example_href.presence || href
      "#{target}#{target.include?("?") ? "&" : "?"}whats_new=#{highlight}"
    end

    def as_page_json(example_href: nil, show_prs: false)
      {
        date: date, title: title, body: body, href: link(example_href),
        screenshots: screenshots.map do |shot|
          { src: "/whats-new/screenshots/#{key}/#{shot.file}?v=#{shot.version}", alt: shot.alt,
            width: shot.width, height: shot.height, phone: shot.phone? }
        end,
        prs: show_prs && WhatsNew::REPO_URL ? prs.map { |n| { number: n, url: "#{WhatsNew::REPO_URL}/pull/#{n}" } } : []
      }
    end
  end

  # Loaded once; the file only changes with a deploy.
  def self.all
    @all ||= newest_first(YAML.safe_load_file(PATH, permitted_classes: [ Date ]).fetch("entries").map { |attrs| Entry.from(attrs) }).freeze
  end

  # Within a date the file's order stands, so the biggest news can lead.
  def self.newest_first(entries)
    entries.group_by(&:date).sort.reverse.flat_map(&:last)
  end

  def self.visible_to(role:, entries: all)
    entries.select { |entry| entry.visible_to?(role: role) }
  end

  def self.find_visible(key, role:)
    visible_to(role: role).find { |entry| entry.key == key }
  end

  # For a "new" dot on the menu item, so a member's dot can't announce an
  # admin's entry.
  def self.latest_date(role:, entries: all)
    visible_to(role: role, entries: entries).map(&:date).max
  end

  # Width and height from a WebP header (lossy VP8, lossless VP8L or extended
  # VP8X), so the page can size a shot before it loads. nil when the file is
  # missing or isn't a WebP; the tests catch both.
  def self.webp_size(path)
    head = File.binread(path, 30)
    return unless head && head.bytesize >= 30 && head[0, 4] == "RIFF" && head[8, 4] == "WEBP"

    case head[12, 4]
    when "VP8 " then head[26, 4].unpack("vv").map { |n| n & 0x3fff }
    when "VP8L"
      bits = head[21, 4].unpack1("V")
      [ (bits & 0x3fff) + 1, ((bits >> 14) & 0x3fff) + 1 ]
    when "VP8X"
      [ head[24, 3], head[27, 3] ].map { |b| (b.bytes[0] | (b.bytes[1] << 8) | (b.bytes[2] << 16)) + 1 }
    end
  rescue Errno::ENOENT
    nil
  end
end
