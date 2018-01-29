class NounBlacklist
  @@patterns = [
    /'s/,
    /is/i,
    /^bigoted$/i,

    /^\*.*\*$/, # surrounded by asterisks
  ]

  ##
  # Any noun that fails to be validated will not get replaced.
  # Noun will remain intact in the original sentence.
  def validate(noun)
    return false if noun.is_proper?

    s = noun.to_s
    return false if s.nil?
    return false if s.length <= 1

    @@patterns.each do |pattern|
      return false if s =~ pattern
    end

    return true
  end
end