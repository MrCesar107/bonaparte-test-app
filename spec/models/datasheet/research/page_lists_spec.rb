require "rails_helper"

RSpec.describe Datasheet::Research::PageLists do
  describe "#call" do
    it "keeps the table lists and does not call the model" do
      rewrite = double("rewrite")
      allow(rewrite).to receive(:call)

      lists = described_class.new(
        body: "<h2>Aplicaciones</h2><table><tr><th>Modelo</th></tr><tr><td>D21</td></tr></table>",
        phrase: phrase("DM-152 QJC20G NISSAN PICKUP 76/14"),
        source_row: build(:source_row, description: "DM-152 QJC20G NISSAN PICKUP 76/14"),
        rewrite: rewrite
      ).call

      expect(lists.applications.map(&:model)).to eq([ "D21" ])
      expect(lists.unconfirmed_tokens).to eq([ "QJC20G" ])
      expect(rewrite).not_to have_received(:call)
    end

    it "keeps empty lists when the page has no tables" do
      rewrite = double("rewrite")
      allow(rewrite).to receive(:call)
      body = "<p>texto de la ficha</p>"

      lists = described_class.new(
        body: body,
        phrase: phrase("DM-152 QJC20G NISSAN PICKUP 1.8 76/14"),
        source_row: build(:source_row, description: "DM-152 QJC20G NISSAN PICKUP 1.8 76/14"),
        rewrite: rewrite
      ).call

      expect(rewrite).not_to have_received(:call)
      expect(lists.applications).to be_empty
      expect(lists.unconfirmed_tokens).to eq([ "QJC20G" ])
    end

    it "adds the oversize only when the page does not already list it" do
      listed = described_class.new(
        body: attribute_table("Sobremedida", "+20"),
        phrase: phrase("SP26-329R/L+20 CHEVROLET SILVERADO", "SP26-329R/L+20", "PISTON"),
        source_row: build(:source_row, description: "SP26-329R/L+20 CHEVROLET SILVERADO"),
        rewrite: unused_rewrite
      ).call
      missing = described_class.new(
        body: "<h2>Aplicaciones</h2><table><tr><th>Modelo</th></tr><tr><td>Silverado</td></tr></table>",
        phrase: phrase("SP26-329R/L+20 CHEVROLET SILVERADO", "SP26-329R/L+20", "PISTON"),
        source_row: build(:source_row, description: "SP26-329R/L+20 CHEVROLET SILVERADO"),
        rewrite: unused_rewrite
      ).call

      expect(listed.attributes.map(&:value)).to eq([ "+20" ])
      expect(missing.attributes.map(&:value)).to eq([ "+20" ])
      expect(missing.attributes.first).to have_attributes(attribute_class: "Sobremedida", name: "Sobremedida")
    end
  end

  def phrase(description, part_number = "RM-152", item_group = "BOMBA DE ACEITE")
    Datasheet::Research::Phrase.new(description: description, part_number: part_number, item_group: item_group).call
  end

  def empty_lists(part_number:, product:)
    described_class::Lists.new(
      part_number: part_number,
      subsystem: "",
      product: product,
      description: "",
      applications: [],
      interchanges: [],
      attributes: [],
      unconfirmed_tokens: []
    )
  end

  def unused_rewrite
    rewrite = double("rewrite")
    allow(rewrite).to receive(:call)
    rewrite
  end

  def attribute_table(name, value)
    <<~HTML
      <h2>Atributos</h2>
      <table>
        <tr><th>Atributo</th><th>Valor</th></tr>
        <tr><td>#{name}</td><td>#{value}</td></tr>
      </table>
    HTML
  end
end
