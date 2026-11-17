require "json"
require "net/http"
require "openssl"

class Datasheet::Research::OutOfCredits < StandardError; end

class Datasheet::Research::SerpApiSearch
  ENDPOINT = URI("https://serpapi.com/search.json")
  OPEN_TIMEOUT = 5
  READ_TIMEOUT = 15
  Result = Data.define(:url, :snippet)

  class Reply < Array
    attr_reader :overview, :references, :page_token

    def initialize(links, overview = "", references: [], page_token: nil)
      super()
      replace(Array(links))
      @overview = overview.to_s
      @references = Array(references)
      @page_token = page_token.presence
    end

    def pending_overview?
      overview.blank? && page_token.present?
    end
  end

  def initialize(api_key: ENV["SERPAPI_API_KEY"], account: Datasheet::Research::SerpApiAccount.new)
    @api_key = api_key
    @account = account
  end

  def call(query)
    payload = fetch_payload(engine: "google", q: query)
    reply_for(organic_results(payload), payload["ai_overview"])
  end

  def resolve_overview(reply)
    return reply unless reply.respond_to?(:pending_overview?) && reply.pending_overview?

    fetched = fetch_payload(engine: "google_ai_overview", page_token: reply.page_token)
    node = fetched["ai_overview"].is_a?(Hash) ? fetched["ai_overview"] : fetched
    return reply unless node.is_a?(Hash)

    Reply.new([], overview_text(node), references: links_from(node["references"]), page_token: reply.page_token)
  end

  private

  def reply_for(listed, node)
    return Reply.new(listed) unless node.is_a?(Hash)

    text = overview_text(node)
    Reply.new(
      listed,
      text,
      references: text.present? ? links_from(node["references"]) : [],
      page_token: text.present? ? nil : node["page_token"]
    )
  end

  def fetch_payload(params)
    raise Datasheet::Research::OutOfCredits if @account.searches_left.zero?
    raise Datasheet::Research::Unavailable if @api_key.blank?

    uri = ENDPOINT.dup
    uri.query = URI.encode_www_form(params.merge(api_key: @api_key))
    response = get(uri)
    @account.consume!
    payload = JSON.parse(response.body)

    if out_of_credits?(response, payload)
      @account.exhaust!
      raise Datasheet::Research::OutOfCredits
    end
    raise Datasheet::Research::Unavailable unless response.is_a?(Net::HTTPSuccess)

    payload
  rescue JSON::ParserError, SocketError, Timeout::Error, SystemCallError, OpenSSL::SSL::SSLError, EOFError
    raise Datasheet::Research::Unavailable
  end

  def get(uri)
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = uri.scheme == "https"
    http.open_timeout = OPEN_TIMEOUT
    http.read_timeout = READ_TIMEOUT
    http.request(Net::HTTP::Get.new(uri))
  end

  def organic_results(payload)
    raise Datasheet::Research::Unavailable if payload["error"].present? && !no_results?(payload)
    return [] if no_results?(payload)

    links_from(payload["organic_results"])
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
