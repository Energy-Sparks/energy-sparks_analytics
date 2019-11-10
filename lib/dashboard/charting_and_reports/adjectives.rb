class Adjective
  ADJECTIVES = {
    relative_to_1: {
      -Float::INFINITY..-0.3  => 'signifcantly below',
      -0.3..-0.1              => 'below',
      -0.1..-0.05             => 'just below',
      -0.05..0.05             => 'about',
      0.05..0.1               => 'just above',
      0.1..0.2                => 'above',
      0.2..Float::INFINITY    => 'significantly'
    },
    simple_relative_to_1: {
      -Float::INFINITY..-0.05  => 'below',
      -0.05..0.05              => 'about',
      0.05..Float::INFINITY    => 'above'
    }
  }
  def self.relative(value, range_to_adjective_map)
    range_to_adjective_map = ADJECTIVES[range_to_adjective_map] if range_to_adjective_map.is_a?(Symbol)
    found = range_to_adjective_map.keys.find { |range| value.between?(range.first, range.last) }
    range_to_adjective_map[found]
  end
end