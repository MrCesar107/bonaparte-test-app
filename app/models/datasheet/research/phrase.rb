class Datasheet::Research::Phrase
  VEHICLE_BRANDS = %w[nissan chevrolet gmc dodge jeep ram chrysler ford gm].freeze
  GROUP_ALIASES = {
    "bomba de aceite" => "oil pump",
    "cadena de tiempo" => "timing chain kit",
    "punteria hidraulica" => "hydraulic lifter",
    "piston" => "piston",
    "empaque" => "gasket set"
  }.freeze

  Result = Data.define(:candidates, :oversize, :years, :group_alias, :queries)

  def self.same_number?(left, right)
    compact_left = compact_number(left)
    compact_right = compact_number(right)

    return false if compact_left.empty? || compact_right.empty?
    return true if compact_left == compact_right

    prefix_letter_variant?(compact_left, compact_right)
  end

  def initialize(description:, part_number:, item_group:)
    @description = description.to_s
    @part_number = part_number.to_s
    @item_group = item_group.to_s
  end

  def call
    Result.new(
      candidates: candidates,
      oversize: oversize,
      years: years,
      group_alias: group_alias,
      queries: queries
    )
  end

  class << self
    private

    def compact_number(value)
      value.to_s.upcase.gsub(/[\s.\/-]/, "")
    end

    def prefix_letter_variant?(left, right)
      left_prefix, left_rest = split_prefix(left)
      right_prefix, right_rest = split_prefix(right)
      return false unless left_rest == right_rest

      digits = left_rest.gsub(/\D/, "")
      return false if digits.length < 5

      longer, shorter = [ left_prefix, right_prefix ].sort_by(&:length).reverse
      one_extra_letter?(longer, shorter)
    end

    def split_prefix(value)
      value.match(/\A([A-Z]*)(.*)\z/).captures
    end

    def one_extra_letter?(longer, shorter)
      return false unless longer.length == shorter.length + 1

      longer.chars.each_index.any? do |index|
        without_letter = longer.dup
        without_letter.slice!(index)
        without_letter == shorter
      end
    end
  end

  private

  def tokens
    @tokens ||= @description.split(/\s+/)
  end

  def brand_index
    return @brand_index if defined?(@brand_index)

    @brand_index ||= tokens.index { |token| VEHICLE_BRANDS.include?(token.downcase) }
  end

  def candidates
    list = []

    if brand_index
      tokens.take(brand_index).each { |token| add_candidate(list, token) }
      add_candidate(list, @part_number)
    else
      add_candidate(list, @part_number)
      tokens.each { |token| add_candidate(list, token) if token.match?(/\d/) }
    end

    list
  end

  def add_candidate(list, token)
    base, = split_token(token)
    return if base.blank? || list.include?(base)

    list << base
  end

  def oversize
    (tokens + [ @part_number ]).filter_map { |token| split_token(token).last }
      .first
  end

  def split_token(token)
    text = token.to_s
    return [ nil, text ] if text.match?(/\A\+\d+(?:\.\d+)?\z/)

    match = text.match(/\A(.+?)(\+\d+(?:\.\d+)?)\z/)
    return [ match[1], match[2] ] if match

    [ text.presence, nil ]
  end

  def years
    tokens.flat_map { |token| years_in(token) }
  end

  def years_in(token)
    if (match = token.match(/\A(\d{2})\/(\d{2})\z/))
      match.captures.map { |year| expand_short_year(year) }
    elsif (match = token.match(/\A(\d{4})\/(\d{4})\z/))
      match.captures
    elsif token.match?(/\A\d{4}\z/)
      [ token ]
    else
      []
    end
  end

  def expand_short_year(year)
    number = year.to_i
    base = number <= 49 && 2000 || 1900
    (base + number).to_s
  end

  def group_alias
    normalized = I18n.transliterate(@item_group).downcase.squish
    key = GROUP_ALIASES.keys.select { |candidate| normalized.include?(candidate) }
      .max_by(&:length)

      GROUP_ALIASES[key]
  end

  def queries
    candidates.index_with { |candidate| query_for(candidate) }
  end

  def query_for(candidate)
    [ %("#{candidate}"), group_alias, *years ].compact_blank.join(" ")
  end
end
