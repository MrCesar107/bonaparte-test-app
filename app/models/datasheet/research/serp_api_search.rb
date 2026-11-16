require "json"
require "net/http"

class Datasheet::Research::OutOfCredits < StandardError; end

class Datasheet::Research::SerpApiSearch
  ENDPOINT = URI("https://serpapi.com/search.json")
  Result = Data.define(:url, :snippet)

  class Reply < Array
    attr_reader :overview

    def initialize(links, overview = "")
      super()
      replace(Array(links))
      @overview = overview.to_s
    end
  end

  def initialize(api_key: ENV["SERPAPI_API_KEY"], account: Datasheet::Research::SerpApiAccount.new)
    @api_key = api_key
    @account = account
  end

  def call(query)
    payload = fetch_payload(engine: "google", q: query)
    listed = organic_results(payload)
    node = overview_node(payload, organic: listed)
    Reply.new((listed + links_from(node && node["references"])).uniq(&:url), overview_text(node))
  end

  private

  def fetch_payload(params)
    raise Datasheet::Research::OutOfCredits if @account.searches_left.zero?
    raise Datasheet::Research::Unavailable if @api_key.blank?

    uri = ENDPOINT.dup
    uri.query = URI.encode_www_form(params.merge(api_key: @api_key))
    response = Net::HTTP.get_response(uri)
    payload = JSON.parse(response.body)

    raise Datasheet::Research::OutOfCredits if out_of_credits?(response, payload)
    raise Datasheet::Research::Unavailable unless response.is_a?(Net::HTTPSuccess)

    payload
  rescue JSON::ParserError, SocketError, Timeout::Error, SystemCallError
    raise Datasheet::Research::Unavailable
  end

  def organic_results(payload)
    raise Datasheet::Research::Unavailable if payload["error"].present? && !no_results?(payload)
    return [] if no_results?(payload)

    links_from(payload["organic_results"])
  end

  def overview_node(payload, organic:)
    overview = payload["ai_overview"]
    return unless overview.is_a?(Hash)
    return overview if overview_text(overview).present?

    token = overview["page_token"].to_s
    return overview if token.blank?

    fetched = fetch_payload(engine: "google_ai_overview", page_token: token)
    node = fetched["ai_overview"].is_a?(Hash) ? fetched["ai_overview"] : fetched
    node.is_a?(Hash) ? node : overview
  rescue Datasheet::Research::Unavailable
    raise unless organic.any?

    overview
  end

  def overview_text(node)
    return "" unless node.is_a?(Hash)

    blocks = Array(node["text_blocks"]).flat_map { |block| block_text(block) }
    (blocks + [ node["snippet"].to_s ]).compact_blank.join("\n")
  end

  def block_text(block)
    lines = [ block["snippet"], block["title"] ]
    Array(block["list"]).each { |item| lines << item["snippet"] << item["title"] }
    lines
  end

  def links_from(items)
    Array(items).filter_map do |item|
      link = item["link"].to_s
      next if link.blank?

      Result.new(url: link, snippet: item["snippet"].to_s)
    end
  end

  def out_of_credits?(response, payload)
    response.code == "429" || payload["error"].to_s.match?(/run out of searches/i)
  end

  def no_results?(payload)
    payload["error"].to_s.match?(/hasn.t returned any results/i)
  end
end
