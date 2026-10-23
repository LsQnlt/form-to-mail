# frozen_string_literal: true

require "minitest/autorun"
require_relative "../lib/hashcash"

class HashcashTest < Minitest::Test
  def test_minted_stamp_is_valid
    stamp = Hashcash.mint("example.org", bits: 8)
    assert Hashcash.valid?(stamp, resource: "example.org", bits: 8)
  end

  def test_rejects_wrong_resource_or_too_few_bits
    stamp = Hashcash.mint("example.org", bits: 8)
    refute Hashcash.valid?(stamp, resource: "other.org", bits: 8)
    refute Hashcash.valid?(stamp, resource: "example.org", bits: 12)
  end

  def test_rejects_old_or_future_dates
    old = Hashcash.mint("example.org", bits: 8, date: Date.today - 2)
    future = Hashcash.mint("example.org", bits: 8, date: Date.today + 1)
    yesterday = Hashcash.mint("example.org", bits: 8, date: Date.today - 1)

    refute Hashcash.valid?(old, resource: "example.org", bits: 8)
    refute Hashcash.valid?(future, resource: "example.org", bits: 8)
    assert Hashcash.valid?(yesterday, resource: "example.org", bits: 8)
  end

  def test_rejects_garbage_and_tampered_counters
    refute Hashcash.valid?("", resource: "example.org", bits: 8)
    refute Hashcash.valid?("1:8:notadate:example.org:sha256:abc:0", resource: "example.org", bits: 8)

    stamp = Hashcash.mint("example.org", bits: 8)
    tampered = stamp.sub(/:\d+\z/, ":999999999")
    refute Hashcash.valid?(tampered, resource: "example.org", bits: 8)
  end

  def test_matches_the_javascript_stamp_format
    stamp = "1:8:#{Date.today.strftime('%y%m%d')}:example.org:sha256:abc123:0"
    parsed = Hashcash.parse(stamp)
    assert_equal "example.org", parsed.resource
    assert_equal 8, parsed.bits
    assert_equal stamp, parsed.to_s
  end
end
