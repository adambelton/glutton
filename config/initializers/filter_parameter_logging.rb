# Be sure to restart your server when you modify this file.

# Configure parameters to be partially matched (e.g. passw matches password) and filtered from the log file.
# Use this to limit dissemination of sensitive information.
# See the ActiveSupport::ParameterFilter documentation for supported notations and behaviors.
Rails.application.config.filter_parameters += [
  :passw, :email, :secret, :token, :_key, :crypt, :salt, :certificate, :otp, :ssn, :cvv, :cvc, :notes, :annotations, :community_username,
  :identity_snapshot, /\Aevidence\z/, :resolution_summary, /\Aresolution\.(?:summary|revision)\z/, /\Aexplanation\z/, /\Areport\.(?:explanation|revision)\z/, /\A(?:input|output|profile)\z/
]
