require "rails_helper"

RSpec.describe Datasheet::Research::PageTables do
  describe "#call" do
    it "reads the lists in page order and keeps a year range closed" do
      lists = described_class.new(page_html).call

      expect(lists.part_number).to eq("M152")
      expect(lists.product).to eq("Bomba de aceite")
      expect(lists.subsystem).to eq("Bombas")
      expect(lists.description).to eq("Párrafo comercial")
      expect(lists.applications.map(&:model)).to eq([ "D21", "Motores LS con AFM" ])
      expect(lists.applications.first).to have_attributes(
        manufacturer: "Nissan",
        submodel: "",
        start_year: "1986",
        end_year: "1994",
        liters: "2.4",
        engine_cc: "2389",
        engine_cid: "",
        engine_cylinders: "4",
        block: "L",
        fuel_type: "Gasolina",
        market: "MEX"
      )
      expect(lists.applications.second).to have_attributes(start_year: "2007", end_year: "")
      expect(lists.interchanges.map(&:origin)).to eq([ "Aftermarket", "OEM" ])
      expect(lists.interchanges.first).to have_attributes(number: "DM-152", brand: "Melling")
      expect(lists.attributes.first).to have_attributes(
        attribute_class: "Altura",
        name: "Altura",
        unit: "mm",
        value: "10"
      )
    end

    it "returns empty lists when the page has no matching tables" do
      lists = described_class.new("<p>sin tablas</p>").call

      expect(lists.applications).to be_empty
      expect(lists.interchanges).to be_empty
      expect(lists.attributes).to be_empty
    end
  end

  describe "#any?" do
    it "is true when one list has rows" do
      expect(described_class.new(page_html).any?).to be(true)
    end

    it "is false when the page has no lists" do
      expect(described_class.new("<p>sin tablas</p>").any?).to be(false)
    end
  end

  def page_html
    <<~HTML
      <h2>Aplicaciones</h2>
      <table>
        <tr>
          <th>Fabricante</th><th>Modelo</th><th>Submodelo</th><th>Vigencia</th>
          <th>Litros</th><th>CC</th><th>CID</th><th>Cilindros</th><th>Bloque</th>
          <th>Tipo de combustible</th><th>Mercado</th>
        </tr>
        <tr>
          <td>Nissan</td><td>D21</td><td></td><td>1986-1994</td>
          <td>2.4</td><td>2389</td><td></td><td>4</td><td>L</td>
          <td>Gasolina</td><td>MEX</td>
        </tr>
        <tr>
          <td>Chevrolet</td><td>Motores LS con AFM</td><td></td><td>desde 2007</td>
          <td></td><td></td><td></td><td></td><td></td>
          <td></td><td></td>
        </tr>
      </table>
      <h2>Intercambios</h2>
      <table>
        <tr><th>Número</th><th>Marca</th></tr>
        <tr><td>DM-152</td><td>Melling</td></tr>
        <tr><td>15010-40F00</td><td>Nissan</td></tr>
      </table>
      <h2>Atributos</h2>
      <table>
        <tr><th>Clase</th><th>Atributo</th><th>Unidad</th><th>Valor</th></tr>
        <tr><td>Altura</td><td>Altura</td><td>mm</td><td>10</td></tr>
      </table>
      <dl>
        <dt>Número de parte</dt><dd>M152</dd>
        <dt>Producto</dt><dd>Bomba de aceite</dd>
        <dt>Subsistema</dt><dd>Bombas</dd>
        <dt>Descripción</dt><dd>Párrafo comercial</dd>
      </dl>
    HTML
  end
end
