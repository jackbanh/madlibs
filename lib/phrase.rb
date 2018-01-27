require 'engtagger'

require_relative 'noun.rb'

class Phrase
  attr_reader :text, :readable, :tagged, :nouns

  def initialize(text, tagger = nil, validator = nil)
    @text, @tagger, @validator = text, tagger, validator

    @tagger = EngTagger.new if @tagger.nil?

    @readable = @tagger.get_readable(@text)
    @tagged = @tagger.add_tags(@text)
    if @tagged.nil?
      raise "@tagged is nil for \"#{text}\""
    end

    @nouns = get_nouns
  end

  # parse the tagged phrase
  def get_nouns
    tagged_nouns = Hash.new(0)

    # count the occurrences of each noun
    @tagged.scan(/<nnp?s?>.+?<\/nnp?s?>/).each do |n|
      tagged_nouns[n] += 1
    end

    # build a hash of nouns and occurrence count
    return tagged_nouns.map do |tagged_noun, count|
      noun = Noun.new_from_tagged(tagged_noun)
      if noun and (@validator.nil? or @validator.validate(noun))
        [noun, count]
      else
        nil
      end
    end.compact.to_h
  end

  def get_word_count
    return @text.split(' ').count
  end

  def generate_placeholder_text(max_removed_nouns = nil)
    
    if max_removed_nouns.nil? or max_removed_nouns == 0
      sample_size = @nouns.count
    else
      sample_size = [max_removed_nouns, @nouns.count].min
    end

    placeholder_text = @text.dup

    # pick a random sample of nouns and replace them
    @nouns.keys.sample(sample_size).each do |noun|
      placeholder_text.gsub!(Regexp.new('\b' + Regexp.escape(noun.to_s) + '\b'), "--#{noun.tag}--")
    end

    return placeholder_text, sample_size
  end

  def to_s
    return text
  end
end
