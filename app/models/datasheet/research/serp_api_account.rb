require "json"
require "net/http"
require "openssl"

# Tracks the SerpApi search balance during a research run so requests stop when credits run out.
# Account connection or response errors are reported as Unavailable.
class Datasheet::Research::SerpApiAccount
  ENDPOINT = URI("https://serpapi.com/account.json")
  OPEN_TIMEOUT = 5
  READ_TIMEOUT = 15

  def initialize(api_key: ENV["SERPAPI_API_KEY"])
    @api_key = api_key
  end

  def searches_left
    return @searches_left if defined?(@searches_left)

    @searches_left = fetch_searches_left
  end

  def consume!
    return unless defined?(@searches_left)

    @searches_left -= 1 if @searches_left.positive?
  end

  def exhaust!
    @searches_left = 0
  end

  private

  def fetch_searches_left
    uri = ENDPOINT.dup
    uri.query = URI.encode_www_form(api_key: @api_key)
    response = get(uri)
    raise Datasheet::Research::Unavailable unless response.is_a?(Net::HTTPSuccess)

    JSON.parse(response.body).fetch("total_searches_left").to_i
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
end
