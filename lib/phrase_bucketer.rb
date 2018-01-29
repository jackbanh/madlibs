require 'set'
require 'engtagger'

require_relative 'phrase.rb'
require_relative 'noun_blacklist.rb'

class PhraseBucketer

  ##
  # Name of the PhraseBucketer, usually the directory name where texts were found
  attr_reader :name

  ##
  # Hash of phrases. Key is number of nouns to replace, value is a set of phrases with placeholders in them.
  attr_reader :phrase_buckets

  ##
  # SortedSet of nouns removed from the texts.
  attr_reader :removed_nouns

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

    @phrase_buckets = {1 => Set.new, 2 => Set.new}

    @options = DEFAULT_OPTIONS.merge(options)
  end

  # Substitute periods in text for a different character so it doesn't get mistakenly split up
  # as a phrase
  def substitute_periods text
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
    
    return nil if phrase =~ /Nobel Prize/i

    return true
  end

  ##
  # Processes a body of text into a list of placeholder phrases and removed nouns.
  # Adds the phrases and removed nouns to the internal state.

  def add_text text
    phrase_buckets, removed_nouns = process_text text
    merge_phrase_buckets_and_nouns phrase_buckets, removed_nouns
  end

  ##
  # Processes a body of text into a list of placeholder phrases and removed nouns.
  # Does not modify the internal state of the instance (useful for map/reduce).

  def process_text text
    return if text.nil?
    text = substitute_periods(text)
    return if text.nil?

    # Create variables to store results and return them
    # Don't write directly to instance variables because that could cause issues in concurrency
    removed_nouns = SortedSet.new
    phrase_buckets = {}

    # Remove newlines from text
    text = text.gsub(/\n/, " ")

    # break text into phrases and process
    split = text.split(/(?<=[\.\!\?])/)
    split.each do |s|
      s = s.gsub(FAKE_PERIOD, ".").strip

      if s.nil? or s.empty?
        next
      end

      phrase = Phrase.new(s, @tgr, @noun_blacklist)

      # Pre-process and discard any invalid phrases
      next unless is_valid_phrase(phrase)
      
      # Extract all the nouns into the removed_nouns list
      removed_nouns.merge(phrase.nouns.map { |n, _| n.stem })

      # Get the phrase with the nouns replaced
      placeholder_phrase, bucket_number = phrase.generate_placeholder_text

      # if phrase meets eligibility requirements
      if bucket_number
        # remove any extra whitespace
        placeholder_phrase.gsub!(/\s{2,}/, " ")

        # create bucket as needed
        if !phrase_buckets.has_key? bucket_number
          phrase_buckets[bucket_number] = Set.new
        end

        # Add phrase to appropriate bucket
        phrase_buckets[bucket_number].add(placeholder_phrase) rescue nil
      end
    end

    return phrase_buckets, removed_nouns
  end

  ##
  # Merges a list of removed nouns and phrases to the PhraseBucketer and returns self.

  def merge_phrase_buckets_and_nouns phrase_buckets, removed_nouns
    if removed_nouns
      @removed_nouns.merge removed_nouns
    end

    if phrase_buckets
      phrase_buckets.each do |bucket_number, set|
        if @phrase_buckets.has_key? bucket_number
          @phrase_buckets[bucket_number].merge(set)
        end
      end
    end

    return self
  end
end