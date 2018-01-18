require 'engtagger'

require_relative 'phrase.rb'

class PhraseBucketer

  attr_reader :phrase_buckets, :name, :tagged_phrase_buckets, :removed_nouns

  NOUN_WILDCARD = "--NOUN--"

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
    :max_words => 13,

    :must_start_with_uppercase => true,
  }

  def initialize(name, options = {})
    @removed_nouns = []
    @name = name
    @tgr = EngTagger.new   
    @phrase_buckets = {1 => [], 2 => []}
    @tagged_phrase_buckets = {1=> [], 2 => []}

    @options = DEFAULT_OPTIONS.merge(options)
  end

  # Determines if a phrase meets the requirements for being written to output
  def get_bucket_number(phrase)
    word_count = phrase.split(" ").count
    noun_count = (phrase.split(NOUN_WILDCARD).count) - 1

    return nil if noun_count < @options[:min_nouns] or noun_count > @options[:max_nouns]
    return nil if word_count < @options[:min_words] or word_count > @options[:max_words]

    return nil if @options[:must_start_with_uppercase] and phrase[0] =~ /[^A-Z]/

    return noun_count
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

  # Processes a string and updates phrase_buckets and removed_nouns
  def add_text(text)
    return [] if text.nil?
    text = substitute_periods(text)
    return [] if text.nil?
    punctuations = text.scan(/[\.\!\?;]/)

    # break text into phrases and process
    text.gsub(/["”\(\)]/," ").gsub("\n"," ").split(/[\.\!\?;]/).collect.with_index do |s, i|
      s = s.strip.gsub(FAKE_PERIOD, ".")
      phrase = Phrase.new(s.strip, @tgr)
      placeholder_phrase = phrase.text

      # do parts-of-speech tagging
      tagged_readable_phrase = phrase.readable
      tagged_phrase = phrase.tagged
      nouns = @tgr.get_nouns(tagged_phrase)
      proper = @tgr.get_proper_nouns(tagged_phrase)

      # Pre-process and discard any invalid phrases
      # Discard any phrase with a proper noun
      if proper && proper.count > 0
        next
      end
      
      # Extract all the nouns into the removed_nouns list
      # Replace all nouns with placeholders
      nouns.each do |noun, _|
        is_plural = tagged_readable_phrase.include?(" #{noun}/NNS ")

        # generate placeholder
        placeholder = NOUN_WILDCARD
        placeholder += "s" if is_plural

        # replace noun with placeholder
        placeholder_phrase.gsub!(Regexp.new('\b' + Regexp.escape(noun) + '\b'), placeholder)

        @removed_nouns.push noun
      end if nouns

      # Post-process and remove any phrase that doesn't meet length requirements
      bucket_number = get_bucket_number(placeholder_phrase)

      # if phrase meets eligibility requirements
      if bucket_number
         # Add phrase to appropriate bucket
         @phrase_buckets[bucket_number].push(placeholder_phrase + (punctuations[i].gsub(";","."))) rescue nil
         placeholder_phrase
      else
        nil
      end
    end

    @removed_nouns = @removed_nouns.compact.uniq.sort
  end
end