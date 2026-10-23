# frozen_string_literal: true

ENV["RACK_ENV"] = "test"
ENV["ALLOWED_ORIGINS"] = "https://example.org, https://preview.example.org"
ENV["MAIL_FROM"] = "site@example.org"
ENV["MAIL_TO"] = "inbox@example.org"
ENV["SMTP_URL"] = "smtp://user%40example.org:secret@smtp.example.net:587"
ENV["HASHCASH_BITS"] = "8"
ENV["RATE_LIMIT_HOUR"] = "2"
ENV["RATE_LIMIT_DAY"] = "3"

require "minitest/autorun"
require "rack/test"
require_relative "../app"

class FormToMailTest < Minitest::Test
  include Rack::Test::Methods

  ORIGIN = "https://example.org"

  def app
    FormToMail
  end

  def setup
    Mail::TestMailer.deliveries.clear
    FormToMail.reset_state!
  end

  def test_root_answers_ok
    get "/"
    assert_equal 200, last_response.status
  end

  def test_serves_the_hashcash_script
    get "/hashcash.js"
    assert_equal 200, last_response.status
    assert_includes last_response.body, "Hashcash.mint"
  end

  def test_sends_the_message_and_redirects_to_the_site
    submit(fields)

    assert_equal 303, last_response.status
    assert_equal "https://example.org/?sent=1", last_response.headers["Location"]

    mail = Mail::TestMailer.deliveries.last
    assert_equal ["inbox@example.org"], mail.to
    assert_equal ["site@example.org"], mail.from
    assert_equal ["ana@example.com"], mail.reply_to
    assert_equal "[example.org] Message de Ana", mail.subject
    assert_includes mail.body.decoded, "Bonjour, un message avec des accents : été."
  end

  def test_redirects_to_the_requested_path_but_never_off_site
    submit(fields.merge("_redirect" => "/contact#form"))
    assert_equal "https://example.org/contact?sent=1#form", last_response.headers["Location"]

    submit(fields.merge("_redirect" => "/?lang=fr"), ip: "10.0.0.2")
    assert_equal "https://example.org/?lang=fr&sent=1", last_response.headers["Location"]

    submit(fields.merge("_redirect" => "//evil.example/phish"), ip: "10.0.0.3")
    assert_equal "https://example.org/?sent=1", last_response.headers["Location"]
  end

  def test_rejects_unknown_origins
    submit(fields, origin: "https://evil.example")
    assert_equal 403, last_response.status
    assert_empty Mail::TestMailer.deliveries
  end

  def test_honeypot_drops_the_message_silently
    submit(fields.merge("website" => "http://spam.example"))
    assert_equal 303, last_response.status
    assert_empty Mail::TestMailer.deliveries
  end

  def test_rejects_missing_fields_and_bad_email
    submit(fields.merge("message" => ""))
    assert_equal 422, last_response.status

    submit(fields.merge("email" => "not an email"))
    assert_equal 422, last_response.status
    assert_empty Mail::TestMailer.deliveries
  end

  def test_rejects_missing_wrong_or_reused_stamps
    submit(fields.merge("hashcash" => ""))
    assert_equal 422, last_response.status

    submit(fields.merge("hashcash" => Hashcash.mint("other.org", bits: 8)))
    assert_equal 422, last_response.status

    stamp = Hashcash.mint("example.org", bits: 8)
    submit(fields.merge("hashcash" => stamp))
    assert_equal 303, last_response.status
    submit(fields.merge("hashcash" => stamp))
    assert_equal 422, last_response.status
    assert_equal 1, Mail::TestMailer.deliveries.size
  end

  def test_limits_messages_per_ip_and_per_day
    2.times { submit(fields) }
    submit(fields)
    assert_equal 429, last_response.status

    submit(fields, ip: "10.0.0.2")
    assert_equal 303, last_response.status
    submit(fields, ip: "10.0.0.3")
    assert_equal 429, last_response.status, "daily limit reached"
    assert_equal 3, Mail::TestMailer.deliveries.size
  end

  def test_smtp_settings_come_from_the_url
    options = FormToMail.smtp_options(ENV["SMTP_URL"])
    assert_equal "smtp.example.net", options[:address]
    assert_equal 587, options[:port]
    assert_equal "user@example.org", options[:user_name]
    assert_equal "secret", options[:password]
    assert options[:enable_starttls_auto]
    refute options[:tls]
  end

  private

  def fields
    {
      "name" => "Ana",
      "email" => "ana@example.com",
      "message" => "Bonjour, un message avec des accents : été.",
      "hashcash" => Hashcash.mint("example.org", bits: 8),
      "website" => ""
    }
  end

  def submit(params, origin: ORIGIN, ip: "10.0.0.1")
    post "/send", params, { "HTTP_ORIGIN" => origin, "REMOTE_ADDR" => ip }
  end
end
