# frozen_string_literal: true

require 'uniqid/version'

# ID uniform generation rules, using SnowFlake algorithm, composed of 64 bits
# | 40 bits: Timestamp (millisecond) | 9 bits: WORKER_ID | 6 bits: SERVER_ID | 2 bits: reserved | 7 bits: serial number|
# VERSION = 1.0.0, Release: 2018-03-08
# Usage: Uniqid.generate_id(work_id, server_id)
module Uniqid
  class Error < StandardError; end

  def self.included(klass)
    klass.extend ClassMethods
  end

  # @params worker_id
  # @params server_id
  module ClassMethods
    # 64 bits
    TOTAL_LEN = 64

    # 40 bits for time in milliseconds
    TIMESTAMP_LEN = 40

    # Start timestamp, 2018-01-01 00:00:00
    TIMESTAMP_START = 1_514_736_000_000
    MAX_TIMESTAMP = -1 ^ (-1 << TIMESTAMP_LEN)

    # 9 bits for worker ID, (0-511)
    WORKER_ID_LEN = 9
    # The maximum number of workers supported, -1:complement0b111111111
    MAX_WORKER_NUM = -1 ^ (-1 << WORKER_ID_LEN)

    # 6 bits for server ID, (0-63)
    SERVER_ID_LEN = 6
    # The maximum number of servers supported, result is 63
    MAX_SERVER_NUM = -1 ^ (-1 << SERVER_ID_LEN)

    # 2 bits reserved, (0-3)
    BAK_ID_LEN = 2
    MAX_BAK_NUM = -1 ^ (-1 << BAK_ID_LEN)

    # 7 bits for serial number in milliseconds, (0-127)
    LOCAL_ID_LEN = 7
    MAX_LOCAL_NUM = -1 ^ (-1 << LOCAL_ID_LEN)

    @last_timestamp = -1 # Save the last timestamp
    @sequence = 0 # Initial value of serial number

    # Prevent the generation time is smaller than the previous time(due to issues such as NTP callback),
    # and keep the incremental trend.
    def next_timestamp(last_timestamp)
      timestamp = (Time.now.to_f * 1000).to_i
      timestamp = (Time.now.to_f * 1000).to_i while timestamp <= last_timestamp
      timestamp
    end

    # @return worker_id[int] 64 bits
    def worker_value(value)
      # Handling parameter exception
      value = 0 if value.to_i > MAX_WORKER_NUM || value.to_i.negative?

      value.to_i << SERVER_ID_LEN + BAK_ID_LEN + LOCAL_ID_LEN # 15 bits left
    end

    def server_value(value)
      left_num = BAK_ID_LEN + LOCAL_ID_LEN

      value = 0 if value.to_i > MAX_SERVER_NUM || value.to_i.negative?

      unless value.present?
        # In development mode, take the random number of the largest supported number
        if Rails.env == 'development'
          rand(MAX_SERVER_NUM) << left_num
        else
          value = 0
        end
      end

      value.to_i << left_num
    end

    # Generate ID
    def generate_id(worker_value, server_value, timestamp = nil)
      server_value = server_value(server_value)
      worker_value = worker_value(worker_value)

      # The reserved position is temporarily random, shifted by 7 bits to the left
      bak_value = (rand(MAX_BAK_NUM) << LOCAL_ID_LEN)

      local_timestamp =
        if timestamp
          (timestamp * 1000).to_i
        else
          (Time.now.to_f * 1000).to_i
        end

      # If the last generation time is the same as the current time, the sequence within milliseconds
      if local_timestamp == @last_timestamp

        # The sequence is self-increasing and only has 7 bits,
        # so it is ANDed with MAX_LOCAL_NUM and removes the high bits
        sequence = (@sequence + 1) & MAX_LOCAL_NUM

        # Check for overflow: whether the sequence exceeds 127 per millisecond,
        # when 127, it is equal to 0 after AND with MAX_LOCAL_NUM
        if sequence.zero?
          # Wait until the next millisecond
          local_timestamp = next_timestamp(@last_timestamp)
        end

      else
        # If it is different from the last generation time, reset the sequence
        # In order to ensure that the mantissa is more random, set a random number in the last digit
        @sequence = rand(1 << LOCAL_ID_LEN)
        sequence = @sequence
      end

      @last_timestamp = local_timestamp

      # Save the difference of timestamp(current timestamp - start timestamp)
      local_timestamp -= TIMESTAMP_START

      (local_timestamp << (TOTAL_LEN - TIMESTAMP_LEN)) | server_value | worker_value | bak_value | sequence
    end

    # Reverse check timestamp
    def get_timestamp(id)
      timestamp = (id >> (TOTAL_LEN - TIMESTAMP_LEN)) / 1000.0
      Time.at(timestamp + TIMESTAMP_START / 1000.0)
    end
  end
end
