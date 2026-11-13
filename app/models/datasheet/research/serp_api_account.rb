require "net/http"

class Datasheet::Research::SerpApiAccount
  ENDPOINT = URI("https://serpapi.com/account.json")

  def initialize(api_key: ENV["SERPAPI_API_KEY"])
    @api_key = api_key
  end

  def searches_left
    uri = ENDPOINT.dup
    uri.query = URI.encode_www_form(api_key: @api_key)
    response = Net::HTTP.get_response(uri)
    raise Datasheet::Research::Unavailable unless response.is_a?(Net::HTTPSuccess)

    JSON.parse(response.body).fetch("total_searches_left").to_i
  rescue JSON::ParserError, SocketError, Timeout::Error, SystemCallError
    raise Datasheet::Research::Unavailable
  end
end
