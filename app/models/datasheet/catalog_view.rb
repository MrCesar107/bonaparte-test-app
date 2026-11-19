# Builds the catalog sections and metrics from stored source rows and the research.

# Matches input fingerprints to store parts and publishes details only from created datasheets.
# Preserves Origen order, sorts catalog references, and expands fitment year ranges.

# Both the screen and Excel export use this view, so publication needs no new searches
# or rereading of the uploaded spreadsheet.
class Datasheet::CatalogView
  View = Data.define(
    :origin, :catalog, :applications, :interchanges, :attributes, :metrics
  )
  OriginRow = Data.define(
    :internal_code, :part_number, :article_description, :description, :item_group,
    :manufacturer, :unit
  )
  CatalogRow = Data.define(
    :reference, :brand, :category, :vehicle_system, :subsystem, :product,
    :description
  )
  ApplicationRow = Data.define(
    :reference, :brand, :product, :position, :manufacturer, :model, :submodel,
    :year, :liters, :engine_cc, :engine_cid, :engine_cylinders, :block, :fuel_type,
    :market
  )
  InterchangeRow = Data.define(
    :reference, :brand, :product, :number, :interchange_brand, :origin
  )
  AttributeRow = Data.define(
    :reference, :brand, :product, :attribute_class, :name, :unit, :value
  )
  Metrics = Data.define(
    :references, :applications, :interchanges, :attributes, :without_sheet
  )

  def initialize(datasheet:)
    @datasheet = datasheet
  end

  def call
    View.new(
      origin: origin, catalog: catalog, applications: applications,
      interchanges: interchanges, attributes: attributes, metrics: metrics
    )
  end

  def origin
    source_rows.map do |row|
      OriginRow.new(
        internal_code: row.internal_code,
        part_number: row.part_number,
        article_description: row.article_description,
        description: row.description,
        item_group: row.item_group,
        manufacturer: row.manufacturer,
        unit: row.unit
      )
    end
  end

  def catalog
    catalog_parts.map { |part| catalog_row(part) }
  end

  def applications
    preload_details(:applications)
    catalog_parts.flat_map { |part| application_rows(part) }
  end

  def interchanges
    preload_details(:interchanges)
    catalog_parts.flat_map { |part| interchange_rows(part) }
  end

  def attributes
    preload_details(:part_attributes)
    catalog_parts.flat_map { |part| attribute_rows(part) }
  end

  def metrics
    preload_details(:applications, :interchanges, :part_attributes)
    metrics_for(catalog_parts)
  end

  private

  def source_rows
    @source_rows ||= @datasheet.source_rows.to_a
  end

  def catalog_parts
    @catalog_parts ||= source_rows.filter_map { |row| part_for(row) }
      .uniq
      .select { |part| part.datasheet.created? }
      .sort_by(&:part_reference)
  end

  def part_for(row)
    parts_by_fingerprint[row.fingerprint]
  end

  def parts_by_fingerprint
    @parts_by_fingerprint ||= Part.for_part_store(@datasheet.part_store_id)
      .where(fingerprint: source_rows.map(&:fingerprint).uniq)
      .preload(:datasheet)
      .index_by(&:fingerprint)
  end

  def preload_details(*associations)
    sheets = catalog_parts.map(&:datasheet).uniq
    ActiveRecord::Associations::Preloader.new(records: sheets, associations: associations).call
  end

  def catalog_row(part)
    CatalogRow.new(
      reference: part.part_reference,
      brand: part.brand,
      category: part.category,
      vehicle_system: part.vehicle_system,
      subsystem: part.subsystem,
      product: part.product,
      description: part.description
    )
  end

  def application_rows(part)
    part.datasheet.applications.sort_by(&:sort_order).flat_map do |application|
      years_for(application).map do |year|
        ApplicationRow.new(
          reference: part.part_reference,
          brand: part.brand,
          product: part.product,
          position: application.position.to_s,
          manufacturer: application.manufacturer,
          model: application.model,
          submodel: application.submodel.to_s,
          year: year,
          liters: application.liters.to_s,
          engine_cc: application.engine_cc.to_s,
          engine_cid: application.engine_cid.to_s,
          engine_cylinders: application.engine_cylinders.to_s,
          block: application.block.to_s,
          fuel_type: application.fuel_type.to_s,
          market: application.market.to_s
        )
      end
    end
  end

  def years_for(application)
    return [ application.start_year ] if application.end_year.blank?

    year_range(application).map(&:to_s)
  end

  def year_range(application)
    application.start_year.to_i..application.end_year.to_i
  end

  def interchange_rows(part)
    part.datasheet.interchanges.sort_by(&:sort_order).map do |interchange|
      InterchangeRow.new(
        reference: part.part_reference,
        brand: part.brand,
        product: part.product,
        number: interchange.number,
        interchange_brand: interchange.brand,
        origin: interchange.origin
      )
    end
  end

  def attribute_rows(part)
    part.datasheet.part_attributes.sort_by(&:sort_order).map do |attribute|
      AttributeRow.new(
        reference: part.part_reference,
        brand: part.brand,
        product: part.product,
        attribute_class: attribute.attribute_class,
        name: attribute.name,
        unit: attribute.unit.to_s,
        value: attribute.value
      )
    end
  end

  def metrics_for(published)
    Metrics.new(
      references: published.size,
      applications: published.sum {
        |part| part.datasheet.applications.sum {
          |application| application.end_year.blank? ? 1 : year_range(application).size
        }
      },
      interchanges: published.sum { |part| part.datasheet.interchanges.size },
      attributes: published.sum { |part| part.datasheet.part_attributes.size },
      without_sheet: source_rows.count { |row| !part_for(row)&.datasheet&.created? }
    )
  end
end
