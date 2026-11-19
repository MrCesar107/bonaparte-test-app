# Owns a store's commercial reference and catalog labels, linked to shared research.
# Builds consistent import attributes for both new research and saved-template reuse.
class Part < ApplicationRecord
  CATEGORY = "Vehículo ligero"
  VEHICLE_SYSTEM = "MOTOR"
  CATALOG_LABELS = {
    "juego de empaque" => [ "JUNTAS Y SISTEMAS DE SELLADO", "JUEGO DE EMPAQUES DE MOTOR" ],
    "bomba de aceite" => [ "BOMBAS", "BOMBA DE ACEITE DEL MOTOR" ],
    "kit de distribucion" => [ "COMPONENTES DEL TREN DE VÁLVULAS", "KIT DE CADENA DE TIEMPO" ],
    "punteria" => [ "COMPONENTES DEL TREN DE VÁLVULAS", "PUNTERÍA HIDRÁULICA" ],
    "piston" => [ "COMPONENTES DEL BLOQUE DE CILINDROS", "PISTÓN DE MOTOR" ]
  }.freeze

  belongs_to :datasheet

  before_save :copy_part_store_id, if: :will_save_change_to_datasheet_id?

  scope :for_part_store, ->(part_store_id) { where(part_store_id: part_store_id) }

  # Builds unsaved import attributes using the input's identity and saved catalog metadata.
  # Missing templates use catalog defaults; callers supply datasheet/store IDs when inserting.
  def self.attributes_for_source(source_row:, template: nil)
    {
      part_reference: source_row.part_number,
      phrase: source_row.description,
      fingerprint: source_row.fingerprint,
      brand: source_row.manufacturer,
      item_group: source_row.item_group,
      category: template&.category || CATEGORY,
      vehicle_system: template&.vehicle_system || VEHICLE_SYSTEM,
      subsystem: template&.subsystem,
      product: template&.product,
      description: template&.description,
      unconfirmed_tokens: template&.unconfirmed_tokens || []
    }
  end

  # Applies the store catalog's group labels to newly extracted research details.
  # Unknown groups keep the source's extracted subsystem and product.
  def self.attributes_for_research(source_row:, lists:)
    labels = catalog_label(source_row.item_group)
    attributes_for_source(source_row: source_row).merge(
      subsystem: labels&.first.presence || lists.subsystem,
      product: labels&.last.presence || lists.product,
      description: lists.description,
      unconfirmed_tokens: lists.unconfirmed_tokens
    )
  end

  # Inserts import rows while leaving existing store/fingerprint pairs unchanged.
  # Returns ActiveRecord's bulk-insert result; callbacks and validations are bypassed.
  def self.insert_fingerprinted(rows, returning: false)
    insert_all(rows, unique_by: :index_parts_on_part_store_id_and_fingerprint, returning: returning)
  end

  def self.catalog_label(item_group)
    return if item_group.blank?

    normalized = I18n.transliterate(item_group).downcase.squish
    key = CATALOG_LABELS.keys.select { |candidate| normalized.include?(candidate) }.max_by(&:length)
    CATALOG_LABELS[key]
  end
  private_class_method :catalog_label

  private

  def copy_part_store_id
    self.part_store_id = datasheet.part_store_id
  end
end
