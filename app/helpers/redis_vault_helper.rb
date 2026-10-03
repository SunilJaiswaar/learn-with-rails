module RedisVaultHelper
  # Each Redis type stores a different Ruby shape, so rendering `value`
  # directly prints a Hash or Array inspection in the key table.
  def redis_value_preview(entry)
    case entry["type"]
    when "zset"
      entry["value"].map { |item| "#{item['member']} (#{item['score'].to_i})" }.join(", ")
    when "hash"
      entry["value"].map { |field, value| "#{field}=#{value}" }.join(" ")
    when "list", "set"
      entry["value"].join(", ")
    else
      entry["value"].to_s
    end
  end
end
