require "nokogiri"
require "pdf-reader"
require "stringio"

class Datasheet::Research::CatalogRows
  PART = /[A-Z0-9][A-Z0-9.\-\/]*\d[A-Z0-9.\-\/]*/i
  INTERCHANGE = /intercambio|interchange|cross\s*ref|reemplazo|equivalen/i
  EXCERPT_LIMIT = 12_000
  EXCERPT_PREFIX = 1_500

  def initialize(body)
    @body = body.to_s
  end

  def confirms?(candidate)
    applications_for(candidate).any?
  end

  def visible_text
    text
  end

  def excerpt(candidates)
    full = visible_text
    return full if full.length <= EXCERPT_LIMIT

    index = mention_index(full, Array(candidates))
    start = index.nil? ? 0 : [ index - EXCERPT_PREFIX, 0 ].max
    full[start, EXCERPT_LIMIT]
  end

  def applications_for(candidate)
    lines.each_with_index.flat_map { |line, index| rows_for(candidate, line, index) }
  end

  private

  def rows_for(candidate, line, index)
    return [] if interchange?(line) || !owns?(line, candidate)

    window = [ index.positive? ? lines[index - 1] : nil, line, lines[index + 1] ].compact.join(" ")
    applications_in(window)
  end

  def lines
    @lines ||= text.split(/\n+/).map(&:squish).reject(&:blank?)
  end

  def mention_index(full, candidates)
    full.scan(PART) do
      token = Regexp.last_match(0)
      next unless candidates.any? { |candidate| Datasheet::Research::Phrase.same_number?(token, candidate) }

      return Regexp.last_match.begin(0)
    end

    nil
  end

  def text
    return pdf_text if pdf?

    document = Nokogiri::HTML(@body)
    document.css("script, style").remove
    document.xpath("//text()").map { |node| node.text.squish }.reject(&:blank?).join("\n")
  end

  def pdf?
    @body.start_with?("%PDF")
  end

  def pdf_text
    PDF::Reader.new(StringIO.new(@body.b)).pages.map(&:text).join("\n")
  rescue PDF::Reader::MalformedPDFError, PDF::Reader::UnsupportedFeatureError
    ""
  end

  def interchange?(line)
    line.match?(INTERCHANGE)
  end

  def owns?(line, candidate)
    token = part_tokens(line).first
    token.present? && Datasheet::Research::Phrase.same_number?(token, candidate)
  end

  def part_tokens(line)
    line.scan(PART).select { |token| part_token?(token) }
  end

  def part_token?(token)
    compact = token.gsub(/[^A-Z0-9]/i, "")
    compact.length >= 4 && compact.match?(/\d/) && compact.match?(/[A-Z]/i) && !compact.match?(/\A\d{4}\z/)
  end

  def applications_in(window)
    brand = window.match(/\b(#{Datasheet::Research::Phrase::VEHICLE_BRANDS.join("|")})\b/i)&.[](1)&.downcase
    return [] if brand.blank?

    label = Datasheet::Research::Phrase::BRAND_LABELS[brand]
    model = model_after(window, brand)
    return [] if model.blank?

    spans = year_spans(window)
    spans = [ [ "", "" ] ] if spans.empty?
    spans.map { |start_year, end_year| application(label, model, start_year, end_year, liters_in(window)) }
  end

  def model_after(window, brand)
    rest = window.split(/\b#{Regexp.escape(brand)}\b/i, 2).last.to_s
    words = rest.split(/\s+/).reject { |word| word.match?(/\A\d{4}(?:\s*-\s*\d{4})?\z/) || part_token?(word) }
    words.first(3).map(&:capitalize).join(" ").squish
  end

  def year_spans(text)
    text.scan(/\b(\d{4})(?:\s*-\s*(\d{4}))?\b/).map { |start_year, end_year| [ start_year, end_year.to_s ] }
  end

  def liters_in(text)
    text[/(\d\.\d)\s*L\b/i, 1].to_s
  end

  def application(manufacturer, model, start_year, end_year, liters)
    Datasheet::Research::PageLists::ApplicationRow.new(
      manufacturer: manufacturer, model: model, submodel: "", start_year: start_year, end_year: end_year,
      liters: liters, engine_cc: "", engine_cid: "", engine_cylinders: "", block: "", fuel_type: "", market: ""
    )
  end
end
