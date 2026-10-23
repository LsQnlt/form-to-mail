# frozen_string_literal: true

require "date"
require "digest"
require "securerandom"

# Hashcash proof of work, compatible with the stamps minted by hashcash.js
# from active_hashcash (https://github.com/BaseSecrete/active_hashcash):
#
#   version:bits:YYMMDD:resource:sha256:rand:counter
#
# A stamp is valid when the SHA-256 of the whole string starts with `bits`
# zero bits, the resource matches, and the date is today or yesterday.
module Hashcash
  Stamp = Struct.new(:version, :bits, :date, :resource, :ext, :rand, :counter) do
    def to_s
      [version, bits, date.strftime("%y%m%d"), resource, ext, rand, counter].join(":")
    end
  end

  module_function

  def parse(string)
    parts = string.to_s.split(":")
    return nil unless parts.size == 7

    Stamp.new(parts[0], Integer(parts[1], 10), Date.strptime(parts[2], "%y%m%d"), *parts[3..6])
  rescue ArgumentError, Date::Error
    nil
  end

  # A client can claim more bits than required, but only within a small margin:
  # authentic? shifts by (256 - bits), so an unbounded bits turns into a giant
  # left shift that allocates gigabytes for a single check.
  BITS_MARGIN = 8

  def valid?(string, resource:, bits:, today: Date.today)
    stamp = parse(string)
    return false unless stamp
    return false unless stamp.resource == resource && stamp.ext == "sha256"
    return false unless stamp.bits.between?(bits, bits + BITS_MARGIN)
    return false unless stamp.date.between?(today - 1, today)

    authentic?(string, stamp.bits)
  end

  def authentic?(string, bits)
    Digest::SHA256.hexdigest(string).hex >> (256 - bits) == 0
  end

  # Mints a stamp the same way the browser does. Used by the tests.
  def mint(resource, bits:, date: Date.today)
    stamp = Stamp.new(1, bits, date, resource, "sha256", SecureRandom.alphanumeric(10), 0)
    stamp.counter += 1 until authentic?(stamp.to_s, bits)
    stamp.to_s
  end
end
