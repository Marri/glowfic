require_relative 'boot'
require 'oauth/rack/oauth_filter'

require 'rails/all'

# Require the gems listed in Gemfile, including any gems
# you've limited to :test, :development, or :production.
Bundler.require(*Rails.groups)

module Glowfic
  ALLOWED_TAGS = %w(b i u sub sup del ins hr p br div span pre code h1 h2 h3 h4 h5 h6 ul ol li dl dt dd a img blockquote q table td th tr strike s strong em big small font cite abbr var samp kbd mark ruby rp rt bdo wbr details summary)
  ALLOWED_ATTRIBUTES = {
    :all => %w(xml:lang class style title lang dir),
    "hr" => %w(width),
    "li" => %w(value),
    "ol" => %w(reversed start type),
    "a" => %w(href hreflang rel target type),
    "del" => %w(cite datetime),
    "table" => %w(width),
    "td" => %w(abbr width),
    "th" => %w(abbr width),
    "blockquote" => %w(cite),
    "cite" => %w(href)
  }

  DISCORD_LINK_GLOWFIC = 'https://discord.gg/Ss6fRFj'
  DISCORD_LINK_CONSTELLATION = 'https://discord.gg/RWUPXQD'

  module Sanitizers
    WRITTEN_CONF = Sanitize::Config.merge(Sanitize::Config::RELAXED,
      elements: ALLOWED_TAGS,
      attributes: ALLOWED_ATTRIBUTES,
    )
    def self.written(text)
      Sanitize.fragment(text, WRITTEN_CONF).html_safe
    end

    DESCRIPTION_CONF = Sanitize::Config.merge(Sanitize::Config::RELAXED,
      elements: ['a'],
      attributes: {'a' => ['href']},
    )
    def self.description(text)
      Sanitize.fragment(text, DESCRIPTION_CONF).html_safe
    end

    def self.full(text)
      Sanitize.fragment(text).html_safe
    end
  end

  class Application < Rails::Application
    # Initialize configuration defaults for originally generated Rails version.
    config.load_defaults 5.2

    # Settings in config/environments/* take precedence over those specified here.
    # Application configuration should go into files in config/initializers
    # -- all .rb files in that directory are automatically loaded.

    # Set Time.zone default to the specified zone and make Active Record auto-convert to this zone.
    # Run "rake -D time" for a list of tasks for finding time zone names. Default is UTC.
    config.time_zone = 'Eastern Time (US & Canada)'

    config.action_view.sanitized_allowed_tags = Glowfic::ALLOWED_TAGS
    config.after_initialize do
      ActionView::Base.sanitized_allowed_attributes += ['style', 'target']
    end
    config.middleware.use Rack::Pratchett
    config.middleware.use OAuth::Rack::OAuthFilter

    # The default locale is :en and all translations from config/locales/*.rb,yml are auto loaded.
    # config.i18n.load_path += Dir[Rails.root.join('my', 'locales', '*.{rb,yml}').to_s]
    # config.i18n.default_locale = :de
  end
end
