class HotwireLabController < ApplicationController
  before_action :require_authentication

  TECHNIQUES = {
    "turbo_drive" => {
      name: "Turbo Drive (Whole-Page SPA Speed)",
      icon: "🚗",
      summary: "Intercepts all link clicks and form submissions, fetches HTML in background, merges <head>, and replaces <body> without full browser reload.",
      dom_effect: "Replaces <body>. Keeps window and JavaScript environment alive.",
      code: "<a href=\"/dashboard\">Dashboard</a>\n# Intercepted automatically! Zero custom JavaScript."
    },
    "turbo_frames" => {
      name: "Turbo Frames (Scoped Sub-trees)",
      icon: "🖼️",
      summary: "Deconstructs pages into independent, lazily-loaded or independently updated contexts. Interactions inside a frame stay inside the frame.",
      dom_effect: "Only matches matching <turbo-frame id=\"...\">. Rest of page remains untouched.",
      code: "<%= turbo_frame_tag \"cart_items\" do %>\n  <%= render @cart_items %>\n<% end %>"
    },
    "turbo_streams" => {
      name: "Turbo Streams (Targeted DOM Mutation)",
      icon: "⚡",
      summary: "Delivers granular DOM updates across 7 actions: append, prepend, replace, update, remove, before, after — via HTTP responses or WebSockets.",
      dom_effect: "Exact targeted DOM mutations without re-rendering the surrounding template.",
      code: "<turbo-stream action=\"append\" target=\"messages\">\n  <template><%= render @message %></template>\n</turbo-stream>"
    },
    "turbo_morph" => {
      name: "Turbo Morphing (Idiomorph Preservation)",
      icon: "🧬",
      summary: "Intelligently morphs existing DOM trees using Idiomorph instead of replacing them. Preserves form inputs, focus, and scroll positions.",
      dom_effect: "Diffs DOM nodes, changes only dirty attributes and text nodes.",
      code: "# In controller\nclass PostsController < ApplicationController\n  # Enables morphing for stream actions\nend"
    },
    "stimulus" => {
      name: "Stimulus Lifecycle (HTML-Augmented JS)",
      icon: "🔌",
      summary: "A modest JavaScript framework designed to enhance server-rendered HTML. Connects JavaScript objects to HTML elements using data-* attributes.",
      dom_effect: "connect() fires when element enters DOM; disconnect() when removed.",
      code: "<div data-controller=\"counter\">\n  <button data-action=\"click->counter#increment\">+</button>\n  <span data-counter-target=\"display\">0</span>\n</div>"
    }
  }.freeze

  def show
    @active_technique = params[:tech].presence || "turbo_drive"
    @technique_data = TECHNIQUES[@active_technique] || TECHNIQUES["turbo_drive"]
  end
end
