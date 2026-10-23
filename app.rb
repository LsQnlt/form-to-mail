# frozen_string_literal: true

require "sinatra/base"
require "mail"
require "uri"
require_relative "lib/hashcash"

# Form-to-mail: receives an HTML form POST from a static site and sends it by
# email. One instance can serve several sites.
#
# Configuration, all through environment variables:
#   SMTP_URL          smtp://user:password@host:port (STARTTLS) or smtps://... (TLS)
#   MAIL_FROM         sender address, on a domain the SMTP relay is allowed to send for
#   MAIL_TO           recipient address
#   ALLOWED_ORIGINS   comma-separated site origins allowed to post, e.g. "https://example.org"
#   HASHCASH_BITS     proof-of-work difficulty, 18 by default
#   RATE_LIMIT_HOUR   max messages per IP per hour, 5 by default
#   RATE_LIMIT_DAY    max messages per day, all sites together, 100 by default
#
# Expected form fields: name, email, message, hashcash (filled by hashcash.js),
# website (honeypot, must stay empty), _redirect (path on the site to go back
# to after sending, "/" by default; "?sent=1" is appended).
class FormToMail < Sinatra::Base
  MESSAGE_MAX_LENGTH = 5000
  FIELD_MAX_LENGTH = 200
  EMAIL_FORMAT = /\A[^@\s]+@[^@\s]+\.[^@\s]+\z/

  set :allowed_origins, ENV.fetch("ALLOWED_ORIGINS").split(",").map(&:strip).reject(&:empty?)
  set :mail_from, ENV.fetch("MAIL_FROM")
  set :mail_to, ENV.fetch("MAIL_TO")
  set :smtp_url, ENV.fetch("SMTP_URL")
  set :hashcash_bits, Integer(ENV.fetch("HASHCASH_BITS", "18"), 10)
  set :rate_limit_hour, Integer(ENV.fetch("RATE_LIMIT_HOUR", "5"), 10)
  set :rate_limit_day, Integer(ENV.fetch("RATE_LIMIT_DAY", "100"), 10)
  set :public_folder, File.expand_path("public", __dir__)
  set :static, true
  set :logging, true
  set :show_exceptions, false
  set :dump_errors, false

  # In-memory state: spent stamps and send timestamps. Lost on restart, which
  # is fine: stamps expire with their date and the limits are per hour and day.
  @state_lock = Mutex.new
  @spent_stamps = {}
  @sent_at = []

  class << self
    attr_reader :state_lock, :spent_stamps, :sent_at

    def reset_state!
      state_lock.synchronize do
        spent_stamps.clear
        sent_at.clear
      end
    end
  end

  get "/" do
    content_type :text
    "ok"
  end

  post "/send" do
    origin = request.env["HTTP_ORIGIN"].to_s
    unless settings.allowed_origins.include?(origin)
      log_result(origin, "forbidden origin")
      halt 403, "forbidden origin"
    end

    redirect_to = origin + redirect_path

    # Honeypot filled: a bot. Pretend everything went well.
    unless params["website"].to_s.empty?
      log_result(origin, "honeypot")
      redirect redirect_to, 303
    end

    name = params["name"].to_s.strip
    email = params["email"].to_s.strip
    message = params["message"].to_s.strip
    halt 422, "missing fields" if name.empty? || email.empty? || message.empty?
    halt 422, "invalid email" unless email.match?(EMAIL_FORMAT) && email.length <= FIELD_MAX_LENGTH
    halt 422, "message too long" if name.length > FIELD_MAX_LENGTH || message.length > MESSAGE_MAX_LENGTH

    stamp = params["hashcash"].to_s
    unless Hashcash.valid?(stamp, resource: URI(origin).host, bits: settings.hashcash_bits) && spend(stamp)
      log_result(origin, "invalid hashcash")
      halt 422, "invalid proof of work, please reload the page and try again"
    end

    unless within_limits?(request.ip)
      log_result(origin, "rate limited")
      halt 429, "too many messages, please try again later"
    end

    deliver(origin, name, email, message)
    log_result(origin, "sent")
    redirect redirect_to, 303
  end

  private

  # Path on the site to go back to, with sent=1 added before any fragment.
  def redirect_path
    path = params["_redirect"].to_s
    path = "/" unless path.start_with?("/") && !path.start_with?("//")
    path, fragment = path.split("#", 2)
    path += path.include?("?") ? "&sent=1" : "?sent=1"
    fragment ? "#{path}##{fragment}" : path
  end

  def spend(stamp)
    self.class.state_lock.synchronize do
      spent = self.class.spent_stamps
      spent.delete_if { |_, seen_at| seen_at < Time.now - 2 * 86_400 }
      return false if spent.key?(stamp)

      spent[stamp] = Time.now
      true
    end
  end

  def within_limits?(ip)
    now = Time.now
    self.class.state_lock.synchronize do
      sent = self.class.sent_at
      sent.delete_if { |_, at| at < now - 86_400 }
      return false if sent.size >= settings.rate_limit_day
      return false if sent.count { |sender, at| sender == ip && at >= now - 3600 } >= settings.rate_limit_hour

      sent << [ip, now]
      true
    end
  end

  def deliver(origin, name, email, message)
    site = URI(origin).host
    mail = Mail.new
    mail.from = settings.mail_from
    mail.to = settings.mail_to
    mail.reply_to = Mail::Address.new.tap { |a| a.address = email; a.display_name = name }.format
    mail.subject = "[#{site}] Message de #{name}"
    mail.body = <<~TEXT
      Message envoyé depuis #{origin}

      Nom : #{name}
      Email : #{email}

      #{message}
    TEXT
    mail.charset = "UTF-8"
    mail.delivery_method(*delivery_method)
    mail.deliver
  end

  def delivery_method
    settings.test? ? [:test] : [:smtp, self.class.smtp_options(settings.smtp_url)]
  end

  def self.smtp_options(smtp_url)
    url = URI(smtp_url)
    {
      address: url.host,
      port: url.port,
      user_name: URI.decode_www_form_component(url.user.to_s),
      password: URI.decode_www_form_component(url.password.to_s),
      authentication: :login,
      tls: url.scheme == "smtps",
      enable_starttls_auto: url.scheme != "smtps"
    }
  end

  def log_result(origin, result)
    logger.info("form-to-mail ip=#{request.ip} origin=#{origin} result=#{result}")
  end
end
