# Merge into config/routes.rb.
get "whats-new", to: "whats_new#index", as: :whats_new
get "whats-new/screenshots/:key/:file", to: "whats_new#screenshot", as: :whats_new_screenshot,
    constraints: { key: /[a-z0-9-]+/, file: /[a-z0-9-]+\.webp/ }, format: false
