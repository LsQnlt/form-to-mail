# frozen_string_literal: true

environment ENV.fetch("RACK_ENV", "production")
bind "tcp://0.0.0.0:#{ENV.fetch('PORT', 3000)}"
threads 0, 4
workers 0
