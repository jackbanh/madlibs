require 'set'
require 'engtagger'

require_relative 'phrase.rb'
require_relative 'noun_blacklist.rb'

class PhraseBucketer

  attr_reader :phrase_buckets, :name, :tagged_phrase_buckets, :removed_nouns

  # A character used to stand in for a period during parsing.  Only used internally.
  FAKE_PERIOD = "\u2024"

  TITLES = [ "Mme.", "Mlle.", "Mr.", "Mrs.", "M.", "Col.", "Sgt.", "Dr.", "Capt.","Hon.", "Prof."]
  NAME_SUFFIXES = ["Esq.","Ph.D","Jr.", "Sr."]

  # A list of abbreviations.  A "." following any of these will not signify a new period.
  ABBREVIATIONS  = TITLES + NAME_SUFFIXES + [
                    "no.", "No.", "anon.", 'ca.', 'lot.', "illus.", "Miss.",
                    "Co.", "inc.", "Inc.", 
                    "Ltd.", "Dept.", 
                    "P.",  "DC.", "D.C.",
                    "Thos.",
                    'Ave.', "St.", "Rd.",
                    'Jan.', "Feb.", "Mar.", "Apr.", "Jun.", "Jul.", "Aug.", "Sept.", "Sep.", "Oct.", "Nov.", "Dec."]

  # options to use when processing a phrase
  DEFAULT_OPTIONS = {
    :min_nouns => 1,
    :max_nouns => 2,
    :min_words => 6,
    :max_words => 20,

    :must_start_with_uppercase => true,
  }

  def initialize(name, options = {})
    @removed_nouns = SortedSet.new
    @name = name
    @tgr = EngTagger.new   
    @noun_blacklist = NounBlacklist.new

    @phrase_buckets = {1 => [], 2 => []}
    @tagged_phrase_buckets = {1=> [], 2 => []}

    @options = DEFAULT_OPTIONS.merge(options)
  end

  # Substitute periods in text for a different character so it doesn't get mistakenly split up
  # as a phrase
  def substitute_periods(text)
    begin
      modified = text.gsub(/b\.\s?(\d{4})/, "b#{FAKE_PERIOD} \\1") || text  # born
      modified.gsub!(/d\.\s?(\d{4})/, "d#{FAKE_PERIOD} \\1")   # died

      initials = modified.scan(/(?:^|\s|\()((?:[A-Zc]\.)+)/) # initials, circas
      initials.each do |i|
        modified.gsub!(i[0], i[0].gsub(".",FAKE_PERIOD,))
      end

      ABBREVIATIONS.each do |title|
        mod_title = title.gsub('.', '\.')
        modified.gsub!(/\b#{mod_title}/, mod_title.gsub('\.', FAKE_PERIOD))
      end

      return modified
    rescue => e
      puts "Problem : #{e}"
      return nil
    end
  end

  def is_valid_phrase(phrase)
    word_count = phrase.get_word_count
    noun_count = phrase.nouns.count

    return nil if noun_count < @options[:min_nouns] or noun_count > @options[:max_nouns]
    return nil if word_count < @options[:min_words] or word_count > @options[:max_words]
    return nil if @options[:must_start_with_uppercase] && phrase.to_s =~ /^[^A-Z]/

    return true
  end

  # Processes a string and updates phrase_buckets and removed_nouns
  def add_text(text)
    return [] if text.nil?
    text = substitute_periods(text)
    return [] if text.nil?
    punctuations = text.scan(/[\.\!\?;]/)

    # break text into phrases and process
    text.gsub(/["”\(\)]/," ").gsub("\n"," ").split(/[\.\!\?;]/).collect.with_index do |s, i|
      s = s.gsub(FAKE_PERIOD, ".").strip

      if s.nil? or s.empty?
        next
      end

      phrase = Phrase.new(s, @tgr, @noun_blacklist)

      # Pre-process and discard any invalid phrases
      next unless is_valid_phrase(phrase)
      
      # Extract all the nouns into the removed_nouns list
      @removed_nouns.merge(phrase.nouns.map { |n, _| n.stem })

      # Get the phrase with the nouns replaced
      placeholder_phrase, bucket_number = phrase.generate_placeholder_text

      # if phrase meets eligibility requirements
      if bucket_number
        # remove any extra whitespace
        placeholder_phrase.gsub!(/\s{2,}/, " ")

         # Add phrase to appropriate bucket
         @phrase_buckets[bucket_number].push(placeholder_phrase + (punctuations[i].gsub(";","."))) rescue nil
         placeholder_phrase
      else
        nil
      end
    end
  end
end