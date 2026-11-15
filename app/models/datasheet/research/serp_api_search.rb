require "net/http"

class Datasheet::Research::OutOfCredits < StandardError; end

class Datasheet::Research::SerpApiSearch
  ENDPOINT = URI("https://serpapi.com/search.json")

  def initialize(api_key: ENV["SERPAPI_API_KEY"], account: Datasheet::Research::SerpApiAccount.new)
    @api_key = api_key
    @account = account
  end

  def call(query)
    raise Datasheet::Research::OutOfCredits if @account.searches_left.zero?
    raise Datasheet::Research::Unavailable if @api_key.blank?

    uri = ENDPOINT.dup
    uri.query = URI.encode_www_form(engine: "google", q: query, api_key: @api_key)
    response = Net::HTTP.get_response(uri)
    payload = JSON.parse(response.body)

    raise Datasheet::Research::OutOfCredits if out_of_credits?(response, payload)
    raise Datasheet::Research::Unavailable unless response.is_a?(Net::HTTPSuccess)
    return [] if no_results?(payload)
    raise Datasheet::Research::Unavailable if payload["error"].present?

    Array(payload["organic_results"]).filter_map { |result| result["link"] }
  rescue JSON::ParserError, SocketError, Timeout::Error, SystemCallError
    raise Datasheet::Research::Unavailable
  end

  private

  def out_of_credits?(response, payload)
    response.code == "429" || payload["error"].to_s.match?(/run out of searches/i)
  end

  def no_results?(payload)
    payload["error"].to_s.match?(/hasn.t returned any results/i)
  end
end
