require 'engtagger'

require_relative 'noun.rb'

class Phrase
  attr_reader :text, :readable, :tagged

  def initialize(text, tagger = nil)
    @text, @tagger = text, tagger

    @tagger = EngTagger.new unless @tagger

    @readable = @tagger.get_readable(@text)
    @tagged = @tagger.add_tags(@text)
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
end
