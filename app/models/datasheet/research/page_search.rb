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
    download_failed = false

    @phrase.candidates.each do |candidate|
      urls = search_urls(candidate)
      return urls if urls.is_a?(Symbol)

      pages, failed = pages_for(urls)
      download_failed ||= failed
      hit = part_number_hit(candidate, pages)
      return hit if hit
    end

    return :retry if download_failed

    :not_found
  end

  def search_urls(candidate)
    Array(@search.call(@phrase.queries[candidate]))
  rescue Datasheet::Research::OutOfCredits
    :out_of_credits
  rescue Datasheet::Research::Unavailable
    :retry
  end

  def pages_for(urls)
    failed = false
    pages = urls.filter_map do |url|
      @fetch.call(url)
    rescue Datasheet::Research::Unavailable
      failed = true
      nil
    end

    [ pages, failed && pages.empty? ]
  end

  def part_number_hit(candidate, pages)
    page = pages.find { |item| same_sheet_number?(item, candidate) }
    hit(candidate, page)
  end

  def same_sheet_number?(page, candidate)
    identity_tokens(page).any? { |token| Datasheet::Research::Phrase.same_number?(token, candidate) }
  end

  def identity_tokens(page)
    text = "#{page.url.to_s.tr("/:?&=", " ")} #{sheet_heading(page.body)}"
    text.split(/\s+/).filter_map { |word|
      token = word.gsub(/\A[^A-Z0-9]+|[^A-Z0-9]+\z/i, "")
      token if token.match?(/\d/) && token.match?(/[A-Z]/i)
    }
  end

  def sheet_heading(body)
    html = body.to_s
    title = html[/<title[^>]*>(.*?)<\/title>/im, 1]
    heading = html[/<h1[^>]*>(.*?)<\/h1>/im, 1]
    [ title, heading ].compact.join(" ")
  end

  def hit(candidate, page)
    return if page.nil?

    Hit.new(equivalent: candidate, url: page.url, body: page.body)
  end
end
