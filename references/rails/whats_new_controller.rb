# frozen_string_literal: true

# What's New: open to any signed-in user, each reader seeing only the entries
# for their role (WhatsNew::AUDIENCES_BY_ROLE).
class WhatsNewController < ApplicationController
  before_action :authenticate_user!   # or however the app requires sign-in

  def index
    role = role_for(current_user)
    entries = WhatsNew.visible_to(role: role).map do |entry|
      entry.as_page_json(example_href: example_href_for(entry), show_prs: role == "admin")
    end

    # Inertia + React. For a server-rendered app, set @entries and render a view.
    render inertia: "WhatsNew/Index", props: { entries: entries }
  end

  # An entry's screenshot, behind the same check as the entry itself. The
  # files sit outside public/, so this is the only way to them; anything the
  # reader can't see is a 404, the same as a file that doesn't exist.
  def screenshot
    entry = WhatsNew.find_visible(params[:key], role: role_for(current_user))
    shot = entry&.screenshot(params[:file])
    return head :not_found unless shot

    response.headers["Cache-Control"] = "private, max-age=86400"
    send_data shot.bytes, type: "image/webp", disposition: "inline"
  end

  private

  # The reader's role, as a key of WhatsNew::AUDIENCES_BY_ROLE.
  def role_for(user)
    user&.role.to_s
  end

  # When an entry names an `example`, return a path to a record this reader can
  # see that actually shows the feature, or nil to fall back to the entry's
  # href. Scope every lookup to what the reader may see. For example:
  #
  #   case entry.example
  #   when "overdue_invoice" then (inv = policy_scope(Invoice).overdue.first) && invoice_path(inv)
  #   end
  def example_href_for(entry)
    nil
  end
end
