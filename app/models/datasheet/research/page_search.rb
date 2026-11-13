class Datasheet::Research::PageSearch
  ATTEMPTS = 3
  Hit = Data.define(:equivalent, :url, :body)
  Page = Data.define(:url, :part_number, :product_count, :group, :interchange_numbers, :body)

  def initialize(phrase:, item_group:, search:, fetch:)
    @phrase = phrase
    @item_group = item_group.to_s
    @search = search
    @fetch = fetch
  end

  def call
    ATTEMPTS.times do
      result = attempt
      return result unless result == :retry
    end

    :failed
  end

  private

  def attempt
    @phrase.candidates.each do |candidate|
      pages = Array(@search.call(@phrase.queries[candidate]).map { |url| @fetch.call(url) })
      hit = part_number_hit(candidate, pages) || interchange_hit(candidate, pages)
      return hit if hit
    rescue Datasheet::Research::OutOfCredits
      return :out_of_credits
    rescue Datasheet::Research::Unavailable
      return :retry
    end

    :not_found
  end

  def part_number_hit(candidate, pages)
    page = pages.find { |item| Datasheet::Research::Phrase.same_number?(item.part_number, candidate) }
    hit(candidate, page)
  end

  def interchange_hit(candidate, pages)
    page = pages.find do |item|
      item.product_count == 1 && same_group?(item) && interchange?(item, candidate)
    end

    hit(candidate, page)
  end

  def interchange?(page, candidate)
    page.interchange_numbers.any? do |number|
      Datasheet::Research::Phrase.same_number?(number, candidate)
    end
  end

  def same_group?(page)
    group = I18n.transliterate(page.group.to_s).downcase
    alias_name = @phrase.group_alias.to_s
    item_group = I18n.transliterate(@item_group).downcase.squish

    group.present? && (group.include?(alias_name) || group.include?(item_group))
  end

  def hit(candidate, page)
    return if page.nil?

    Hit.new(equivalent: candidate, url: page.url, body: page.body)
  end
end
