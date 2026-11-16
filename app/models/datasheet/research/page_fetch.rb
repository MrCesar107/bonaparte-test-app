require "json"
require "net/http"
require "nokogiri"
require "openssl"

class Datasheet::Research::PageFetch
  OPEN_TIMEOUT = 5
  READ_TIMEOUT = 15
  REDIRECTS = 5
  USER_AGENT = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/131.0.0.0 Safari/537.36"
  PART_NUMBER_LABEL = /
    (?:part\s*(?:number|no\.?|\#)|n[uú]mero\s+de\s+parte|sku|mpn)
    \s*[\#:]?\s*
    ([A-Z0-9][A-Z0-9.\-\/]*)
  /ix
  INTERCHANGE_HEADING = /intercambio|interchange|cross\s*ref|reemplazo|equivalen/i

  def call(url)
    body, final_url = download(url)
    return blank_page(final_url) if body.blank?

    page_from(final_url, body)
  rescue SocketError, Timeout::Error, SystemCallError, OpenSSL::SSL::SSLError, EOFError
    raise Datasheet::Research::Unavailable
  end

  private

  def download(url)
    uri = URI.parse(url.to_s)
    return [ "", url.to_s ] unless uri.is_a?(URI::HTTP)

    response, final_uri = request(uri, REDIRECTS)
    return [ "", final_uri.to_s ] if response.nil? || !response.is_a?(Net::HTTPSuccess)

    [ page_body(response.body), final_uri.to_s ]
  rescue URI::InvalidURIError
    [ "", url.to_s ]
  end

  def request(uri, redirects)
    return [ nil, uri ] unless uri.is_a?(URI::HTTP)

    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = uri.scheme == "https"
    http.open_timeout = OPEN_TIMEOUT
    http.read_timeout = READ_TIMEOUT
    get = Net::HTTP::Get.new(uri)
    get["User-Agent"] = USER_AGENT
    get["Accept"] = "text/html,application/xhtml+xml,application/pdf"
    response = http.request(get)
    return [ response, uri ] unless response.is_a?(Net::HTTPRedirection) && redirects.positive?

    location = response["location"].to_s
    return [ response, uri ] if location.blank?

    request(URI.join(uri, location), redirects - 1)
  rescue URI::InvalidURIError
    [ nil, uri ]
  end

  def page_from(url, body)
    return pdf_page(url, body) if body.start_with?("%PDF")

    lists = Datasheet::Research::PageTables.new(body).call
    products = json_products(body)
    part_number = part_number_from(lists, products, body, url)

    Datasheet::Research::PageSearch::Page.new(
      url: url,
      part_number: part_number,
      product_count: product_count(products, part_number),
      group: group_from(lists, products, body),
      interchange_numbers: interchange_numbers(lists, body),
      body: body
    )
  end

  def part_number_from(lists, products, body, url)
    lists.part_number.presence ||
      products.filter_map { |item| item["sku"].presence || item["mpn"].presence }.first ||
      itemprop(body, "sku").presence ||
      labeled_part_number(body).presence ||
      heading_part_number(body, url).to_s
  end

  def heading_part_number(body, url)
    heading_tokens = part_tokens(heading_text(body))
    url_tokens = part_tokens(path_text(url))

    (url_tokens & heading_tokens).first || heading_tokens.first || url_tokens.first
  end

  def heading_text(body)
    document = document(body)
    [
      document.at_css("h1")&.text,
      document.at_css("title")&.text,
      document.at_css('meta[property="og:title"]')&.[]("content")
    ].compact.join(" ")
  end

  def path_text(url)
    uri = URI.parse(url.to_s)
    "#{uri.path} #{uri.query}".tr("/", " ")
  rescue URI::InvalidURIError
    ""
  end

  def part_tokens(text)
    text.to_s.split(/\s+/).filter_map { |word|
      token = word.gsub(/\A[^A-Z0-9]+|[^A-Z0-9]+\z/i, "")
      token if part_token?(token)
    }
  end

  def part_token?(token)
    compact = token.gsub(/[^A-Z0-9]/i, "")
    compact.length >= 4 && compact.match?(/\d/) && compact.match?(/[A-Z]/i) && !compact.match?(/\A\d{4}\z/)
  end

  def product_count(products, part_number)
    return products.size if products.any?
    return 1 if part_number.present?

    0
  end

  def group_from(lists, products, body)
    lists.product.presence ||
      products.filter_map { |item| category_name(item) }.first ||
      itemprop(body, "category").presence ||
      document(body).at_css("h1")&.text.to_s.squish
  end

  def interchange_numbers(lists, body)
    from_tables = lists.interchanges.filter_map { |row| row.number.presence }
    (from_tables + text_interchanges(body)).uniq
  end

  def text_interchanges(body)
    heading = document(body).xpath("//*[self::h1 or self::h2 or self::h3 or self::h4]").find { |node|
      node.text.match?(INTERCHANGE_HEADING)
    }
    return [] unless heading

    block = heading.xpath("following-sibling::*[1]")
    cells = block.css("li, td, dd")
    texts = cells.any? ? cells.map(&:text) : [ block.text ]

    texts.flat_map { |text| part_tokens(text) }
  end

  def category_name(item)
    category = item["category"]
    return category if category.is_a?(String) && category.present?

    item["name"].presence
  end

  def json_products(body)
    document(body).css('script[type="application/ld+json"]').flat_map do |node|
      product_nodes(JSON.parse(node.text))
    rescue JSON::ParserError
      []
    end
  end

  def product_nodes(data)
    items = data.is_a?(Hash) && data["@graph"] ? data["@graph"] : data
    Array(items).select { |item| item.is_a?(Hash) && Array(item["@type"]).join(" ").match?(/Product/i) }
  end

  def itemprop(body, name)
    document(body).at_css("[itemprop='#{name}']")&.text.to_s.squish
  end

  def labeled_part_number(body)
    document(body).text[PART_NUMBER_LABEL, 1].to_s.squish
  end

  def document(body)
    @documents ||= {}
    @documents[body] = Nokogiri::HTML(body) unless @documents.key?(body)
    @documents[body]
  end

  def page_body(body)
    raw = body.to_s
    return raw.dup.force_encoding(Encoding::BINARY) if raw.start_with?("%PDF")

    utf8(raw)
  end

  def utf8(text)
    text.to_s.dup.force_encoding(Encoding::UTF_8).scrub
  end

  def pdf_page(url, body)
    Datasheet::Research::PageSearch::Page.new(
      url: url,
      part_number: "",
      product_count: 0,
      group: "",
      interchange_numbers: [],
      body: body
    )
  end

  def blank_page(url)
    Datasheet::Research::PageSearch::Page.new(
      url: url,
      part_number: "",
      product_count: 0,
      group: "",
      interchange_numbers: [],
      body: ""
    )
  end
end
