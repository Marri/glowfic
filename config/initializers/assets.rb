# Be sure to restart your server when you modify this file.

Rails.application.configure do
  # Version of your assets, change this if you want to expire all your assets.
  config.assets.version = '1.0'

  # Add additional assets to the asset load path.
  # Rails.application.config.assets.paths << Emoji.images_path
  # Add Yarn node_modules folder to the asset load path.
  config.assets.paths << Rails.root.join('node_modules')

  # Precompile additional assets.
  # application.js, application.css, and all non-JS/CSS in the app/assets
  # folder are already added.
  config.assets.precompile += [/\w+\/*.js/]

  config.assets.precompile << "accept_tos.js"
  config.assets.precompile << "blocks.js"
  config.assets.precompile << "board_sections.js"
  config.assets.precompile << "global.js"
  config.assets.precompile << "icons.js"
  config.assets.precompile << "messages.js"
  config.assets.precompile << "paginator.js"
  config.assets.precompile << "reorder.js"
  config.assets.precompile << "application_deferred.js"
  config.assets.precompile << "datetimes.js"

  config.assets.precompile += %w( layouts/*.css tinymce.css )
end
