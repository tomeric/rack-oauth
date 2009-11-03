# Be sure to restart your server when you modify this file.

# Your secret key for verifying cookie session data integrity.
# If you change this key, all old sessions will become invalid!
# Make sure the secret is at least 30 characters and all random, 
# no regular words or you'll be exposed to dictionary attacks.
ActionController::Base.session = {
  :key         => '_rails-example_session',
  :secret      => 'fc8ae74cfcbd707ce60eafbaa8b826e5e6ce9c2b0d6de28ea260ef2cff98aa617f01df7cc7679a9acd56b54e8eaf034e9cb06b00c51041776b491524a71083b8'
}

# Use the database for sessions instead of the cookie-based default,
# which shouldn't be used to store highly confidential information
# (create the session table with "rake db:sessions:create")
# ActionController::Base.session_store = :active_record_store
