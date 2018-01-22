require 'active_support/inflector'
require_relative 'configure_inflections.rb'

class Noun
  attr_reader :noun, :stem, :is_proper, :is_plural, :is_common_with_capital, :stem, :tag

  def initialize(noun, is_proper, is_plural)
    @noun, @is_proper, @is_plural = noun, is_proper, is_plural

    @is_common_with_capital = !is_proper && noun[0] =~ /[A-Z]/

    @stem = @noun
    @stem = @stem.singularize if is_plural
    @stem = @stem.downcase unless is_proper

    @tag = 'nn'
    @tag += 'p' if is_proper
    @tag += 's' if is_plural
    @tag.upcase! if is_common_with_capital
  end

  def self.new_from_tagged(tagged_noun)
    # tags are from https://github.com/yohasebe/engtagger/blob/master/lib/engtagger.rb
    # nn, nnp, nnps, nns
    match = tagged_noun.match(/<nn(?<proper>p)?(?<plural>s)?>(?<noun>.+?)<\/nn\w*>/)
    return self.new(match[:noun], !match[:proper].nil?, !match[:plural].nil?)
  end

  def to_s
    return @noun
  end
end
