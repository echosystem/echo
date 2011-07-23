# Settings specified here will take precedence over those in config/environment.rb

# The production environment is meant for finished, "live" apps.
# Code is not reloaded between requests
config.cache_classes = true

# Full error reports are disabled and caching is turned on
config.action_controller.consider_all_requests_local = false
config.action_controller.perform_caching             = true
config.action_view.cache_template_loading            = true

# See everything in the log (default is :info)
config.log_level = :error

# Use a different logger for distributed setups
# config.logger = SyslogLogger.new

# Use a different cache store in production
# config.cache_store = :mem_cache_store

# Enable serving of images, stylesheets, and javascripts from an asset server
# config.action_controller.asset_host = "http://assets.example.com"

# Disable delivery errors, bad email addresses will be ignored
# config.action_mailer.raise_delivery_errors = false

# Enable threaded mode
# config.threadsafe!

# Hosts
OLD_ECHO_HOST = 'echologic.org' # For deep link redirection (with 301)
ECHO_HOST = 'echo.to'
ECHOSOCIAL_HOST = 'www.echosocial.org'

# Feedback recipient
FEEDBACK_RECIPIENT = 'team@echologic.org'

# For using link_to and url_for in ActionMailer, hostname has to be given.
config.action_mailer.default_url_options = { :host => 'echo.to' }

# Number of children statements shown
TOP_CHILDREN = 3
MORE_CHILDREN = 7
TOP_ALTERNATIVES = 2