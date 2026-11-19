# This class searches the equivalent part candidates in order
# and selecting a source with usable fitments by the PageLists class.

# Checks the candidate's identity before accepting details from a result page.

# Tries queries with and without year hints, and retries unavailable searches or downloads.

# Keeps an AI overview only as a fallback while later candidates can still yield a page.

# Returns the selected source or a distinct missing, failed, or exhausted-credit outcome.
class Datasheet::Research::PageSearch
  ATTEMPTS = 3
  Hit = Data.define(:equivalent, :url, :body, :overview, :lists) do
    def initialize(equivalent:, url:, body:, overview: "", lists: nil)
      super(equivalent:, url:, body:, overview:, lists:)
    end
  end
  Page = Data.define(:url, :part_number, :product_count, :group, :interchange_numbers, :body)
  Lead = Data.define(:url, :snippet)

  def initialize(phrase:, source_row:, item_group:, search:, fetch:, rewrite: Datasheet::Research::PageRewrite.new)
    @phrase = phrase
    @source_row = source_row
    @item_group = item_group.to_s
    @search = search
    @fetch = fetch
    @rewrite = rewrite
    @overview = ""
  end

  def call
    answered = false
    pending_overview = nil

    @phrase.candidates.each do |candidate|
      result = search_candidate(candidate)
      return result if result == :out_of_credits
      if result.is_a?(Hit)
        return result if result.url.present?

        pending_overview ||= result
        answered = true
        next
      end

      answered = true if result == :not_found
    end

    return pending_overview if pending_overview

    answered ? :not_found : :failed
  end

  private

  def search_candidate(candidate)
    result = search_query(candidate, @phrase.queries[candidate])
    return result if page?(result) || result == :out_of_credits || result == :failed

    bare = @phrase.bare_queries[candidate]
    return result if bare == @phrase.queries[candidate]

    bare_result = search_query(candidate, bare)
    return bare_result if page?(bare_result) || bare_result == :out_of_credits || bare_result == :failed
    return result if result.is_a?(Hit)
    return bare_result if bare_result.is_a?(Hit)

    :not_found
  end

  def page?(result)
    result.is_a?(Hit) && result.url.present?
  end

  def search_query(candidate, query)
    reply = search_reply(query)
    return reply if reply == :out_of_credits || reply == :failed

    organic = leads_from(reply)
    pages, organic_failed = pages_for(organic)
    found = part_number_hit(candidate, pages)
    return found if found

    overview = load_overview(reply)
    return :out_of_credits if overview == :out_of_credits
    if overview == :overview_unavailable
      return :failed if pages.empty?

      overview = reply
    end

    citations = citation_leads(overview, organic)
    citation_pages, citation_failed = pages_for(citations)
    found = part_number_hit(candidate, citation_pages)
    return found if found

    @overview = text_of(overview)
    found = overview_hit(candidate)
    return found if found
    return :failed if downloads_failed?(organic, organic_failed, citations, citation_failed)

    :not_found
  end

  def search_reply(query)
    ATTEMPTS.times do |attempt|
      return @search.call(query)
    rescue Datasheet::Research::OutOfCredits
      return :out_of_credits
    rescue Datasheet::Research::Unavailable
      return :failed if attempt == ATTEMPTS - 1
    end
  end

  def load_overview(reply)
    return reply unless reply.respond_to?(:pending_overview?) && reply.pending_overview?

    ATTEMPTS.times do |attempt|
      return @search.resolve_overview(reply)
    rescue Datasheet::Research::OutOfCredits
      return :out_of_credits
    rescue Datasheet::Research::Unavailable
      return :overview_unavailable if attempt == ATTEMPTS - 1
    end
  end

  def leads_from(reply)
    Array(reply).map { |item| lead(item) }
  end

  def citation_leads(reply, organic)
    return [] unless reply.respond_to?(:references)

    seen = organic.map(&:url)
    Array(reply.references).filter_map { |item|
      found = lead(item)
      found unless found.url.blank? || seen.include?(found.url)
    }
  end

  def text_of(reply)
    return "" unless reply.respond_to?(:overview)

    reply.overview.to_s
  end

  def downloads_failed?(organic, organic_failed, citations, citation_failed)
    return false if organic.empty? && citations.empty?

    organic_down = organic.empty? || organic_failed
    citations_down = citations.empty? || citation_failed
    organic_down && citations_down && (organic_failed || citation_failed)
  end

  def lead(item)
    return Lead.new(url: item.url.to_s, snippet: item.snippet.to_s) if item.respond_to?(:url)

    Lead.new(url: item.to_s, snippet: "")
  end

  def pages_for(leads)
    failed = false
    pages = leads.filter_map do |item|
      [ fetch_page(item.url), item.snippet ]
    rescue Datasheet::Research::Unavailable
      failed = true
      nil
    end

    [ pages, failed && pages.empty? ]
  end

  def fetch_page(url)
    ATTEMPTS.times do |attempt|
      return @fetch.call(url)
    rescue Datasheet::Research::Unavailable
      raise if attempt == ATTEMPTS - 1
    end
  end

  def part_number_hit(candidate, pages)
    pages.each do |page, snippet|
      next unless accepts?(page, snippet, candidate)

      found = with_lists(hit(candidate, page))
      return found if found
    end

    nil
  end

  def accepts?(page, snippet, candidate)
    return true if same_sheet_number?(page, candidate)
    return false if other_sheet?(page, candidate)
    return true if prose?(page, snippet, candidate)

    catalog = Datasheet::Research::CatalogRows.new(page.body)
    catalog.confirms?(candidate) && (pdf?(page.body) || mentions?(snippet, candidate))
  end

  def other_sheet?(page, candidate)
    number = page.part_number.to_s
    number.present? && !Datasheet::Research::Phrase.same_number?(number, candidate)
  end

  def prose?(page, snippet, candidate)
    return false if pdf?(page.body)

    mentions?(snippet, candidate) && mentions?(page.body, candidate)
  end

  def pdf?(body)
    body.to_s.start_with?("%PDF")
  end

  def mentions?(snippet, candidate)
    Datasheet::Research::Phrase.mentioned?(snippet, candidate)
  end

  def overview_hit(candidate)
    text = @overview.to_s
    return if text.blank? || !mentions?(text, candidate)

    with_lists(Hit.new(equivalent: candidate, url: "", body: text, overview: text))
  end

  def with_lists(found)
    return if found.nil?

    reader = Datasheet::Research::PageLists.new(
      body: found.body,
      overview: found.overview,
      phrase: @phrase,
      source_row: @source_row,
      rewrite: @rewrite
    )
    lists = reader.call
    return unless reader.from_page?
    return unless number_confirmed?(found, reader, lists)

    found.with(lists: lists)
  rescue Datasheet::Research::Unavailable
    nil
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

  def number_confirmed?(found, reader, lists)
    return true unless reader.from_model?

    Datasheet::Research::Phrase.same_number?(lists.part_number, found.equivalent)
  end

  def hit(candidate, page)
    return if page.nil?

    Hit.new(equivalent: candidate, url: page.url, body: page.body)
  end
end
