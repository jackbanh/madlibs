require 'engtagger'

require_relative 'noun.rb'

class Phrase
  attr_reader :text, :readable, :tagged, :nouns

  def initialize(text, tagger = nil)
    @text, @tagger = text, tagger

    @tagger = EngTagger.new unless @tagger

    @readable = @tagger.get_readable(@text)
    @tagged = @tagger.add_tags(@text)
    if @tagged.nil?
      raise "@tagged is nil for \"#{text}\""
    end

    @nouns = get_nouns
  end

  # parse the tagged phrase
  def get_nouns
    # build a hash of nouns and occurrences
    tagged_nouns = Hash.new(0)
    @tagged.scan(/<nnp?s?>.+?<\/nnp?s?>/).each do |n|
      tagged_nouns[n] += 1
    end

    return tagged_nouns.map do |tagged_noun, count|
      noun = Noun.new_from_tagged(tagged_noun)
      if noun
        [noun, count]
      else
        nil
      end
    end.compact.to_h
  end

  def get_word_count
    return @text.split(' ').count
  end

  def generate_placeholder_text
    sample_size = @nouns.count

    placeholder_text = @text.dup

    # pick a rnadom sample of nouns and replace them
    @nouns.keys.sample(sample_size).each do |noun|
      placeholder_text.gsub!(Regexp.new('\b' + Regexp.escape(noun.to_s) + '\b'), noun.tag)
    end

    return placeholder_text
  end

  def to_s
    return text
  end
end
