# frozen_string_literal: true

module SolidQueueBoard
  class Engine < ::Rails::Engine
    isolate_namespace SolidQueueBoard

    config.i18n.load_path += Dir[root.join("config", "locales", "*.yml")]
  end

  # CSS and JS ship inside the gem and are inlined in the layout: no asset pipeline,
  # no CDN, nothing for the host application to import or precompile.
  module Web
    DIR = Engine.root.join("lib", "solid_queue_board", "web")

    def self.css = read("board.css")
    def self.js = read("board.js")

    def self.read(name)
      return File.read(DIR.join(name)) if Rails.env.development?

      (@cache ||= {})[name] ||= File.read(DIR.join(name)).freeze
    end
  end
end
