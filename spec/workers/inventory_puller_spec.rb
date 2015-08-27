require 'spec_helper'

describe Workers::InventoryPuller do
  before(:each) do
    Spree::Variant.any_instance.stub(:ensure_color_code)
    Spree::Variant.any_instance.stub(:enqueue_product_for_reindex)
  end

  describe '#perform' do
    let(:fake_response) { double('Response').as_null_object }

    before do
      allow(Spree::Newgistics::HTTPManager).to receive(:get) { fake_response }
    end

    context 'when inventory response is successful' do
      before do
        fake_response.stub status: 200, body: <<-XML
          <?xml version="1.0"?>
          <response>
            <products>
              <product id="78388" sku="PRODUCT-SKU-001">
                <currentQuantity>19901</currentQuantity>
                <pendingQuantity>0</pendingQuantity>
                <availableQuantity>19901</availableQuantity>
                <backorderedQuantity>0</backorderedQuantity>
              </product>
              <product id="78389" sku="PRODUCT-SKU-002">
                <currentQuantity>15</currentQuantity>
                <pendingQuantity>3</pendingQuantity>
                <availableQuantity>12</availableQuantity>
                <backorderedQuantity>0</backorderedQuantity>
              </product>
              <product id="78389" sku="PRODUCT-SKU-003">
                <currentQuantity>432</currentQuantity>
                <pendingQuantity>0</pendingQuantity>
                <availableQuantity>432</availableQuantity>
                <backorderedQuantity>0</backorderedQuantity>
              </product>
              <product id="78389" sku="PRODUCT-SKU-004">
                <currentQuantity>0</currentQuantity>
                <pendingQuantity>0</pendingQuantity>
                <availableQuantity>0</availableQuantity>
                <backorderedQuantity>2</backorderedQuantity>
              </product>
            </products>
            <errors></errors>
          </response>
        XML
      end

      it 'updates the inventory' do
        expect(subject).to receive :update_inventory
        subject.perform
      end

    end

    context 'when inventory response is unsuccessful' do

      before do
        fake_response.stub status: 422
      end

      it 'does not update the inventory' do
        expect(subject).not_to receive :update_inventory
        subject.perform
      end

    end

  end

  describe "#update_inventory" do

    context "when variant's stock item is less than 0" do
      let(:variant) { create :variant, sku: '1234' }

      before do
        variant
      end

      context 'because ng availableQuantity is below 0' do
        let(:response) do
          [
            {
              "id"=>"1148187",
              "sku"=>"1234",
              "currentQuantity"=>"6",
              "receivingQuantity"=>"0",
              "arrivedPutAwayQuantity"=>"0",
              "kittingQuantity"=>"0",
              "returnsQuantity"=>"0",
              "pendingQuantity"=>"0",
              "availableQuantity"=>"-1",
              "backorderedQuantity"=>"0"
            }
          ]
        end

        it 'sends a slack message' do
          expect(Alerts).to receive(:slack_notify)
          subject.update_inventory(response)
        end
      end

      context 'because stock item count on hand is below 0' do
        let(:response) do
          [
            {
              "id"=>"1148187",
              "sku"=>"1234",
              "currentQuantity"=>"6",
              "receivingQuantity"=>"0",
              "arrivedPutAwayQuantity"=>"0",
              "kittingQuantity"=>"0",
              "returnsQuantity"=>"0",
              "pendingQuantity"=>"0",
              "availableQuantity"=>"6",
              "backorderedQuantity"=>"0"
            }
          ]
        end

        let(:stock_item) { double('StockItem').as_null_object }

        before do
          Spree::Variant.any_instance.stub_chain(:stock_items, :find_by) { stock_item }
          stock_item.stub count_on_hand: -1
        end

        it 'sends a slack message' do
          expect(Alerts).to receive(:slack_notify)
          subject.update_inventory(response)
        end
      end

      context 'when slack notification fails' do
        let(:response) do
          [
            {
              "id"=>"1148187",
              "sku"=>"1234",
              "currentQuantity"=>"6",
              "receivingQuantity"=>"0",
              "arrivedPutAwayQuantity"=>"0",
              "kittingQuantity"=>"0",
              "returnsQuantity"=>"0",
              "pendingQuantity"=>"0",
              "availableQuantity"=>"-1",
              "backorderedQuantity"=>"0"
            }
          ]
        end

        let(:log) { double('Log').as_null_object }

        it 'logs an error' do
          allow(File).to receive(:open) { log }
          expect(Alerts).to receive(:slack_notify) { false }
          expect(log).to receive(:<<).with "CRITICAL: Can't send slack notification, please check settings\n"
          subject.update_inventory(response)
        end
      end
    end

    context "when variant's stock items change from 0 to greater than 0" do

      let(:variant) { create :variant, sku: '1234' }

      it "variant should be in stock" do
        response = [
          {
            "id"=>"1148187",
            "sku"=>"1234",
            "currentQuantity"=>"6",
            "receivingQuantity"=>"0",
            "arrivedPutAwayQuantity"=>"0",
            "kittingQuantity"=>"0",
            "returnsQuantity"=>"0",
            "pendingQuantity"=>"0",
            "availableQuantity"=>"6",
            "backorderedQuantity"=>"0"
          }
        ]

        expect{subject.update_inventory(response)}.to change{variant.in_stock?}.from(false).to(true)
      end
    end

    context "level sync process" do

      let(:variant) { create :variant, sku: '1234' }
      let(:random) { Random.new }

      context "there is no not sync'ed orders" do
        it "should change count_on_hold on data from NG" do
          first_stock_item = variant.stock_items.first
          count_on_hold = first_stock_item.count_on_hold + random.rand(100) + 1
          response = [
            {
              "id"=>"1148187",
              "sku"=>"1234",
              "currentQuantity"=>"6",
              "receivingQuantity"=>"0",
              "arrivedPutAwayQuantity"=>"0",
              "kittingQuantity"=>"0",
              "returnsQuantity"=>"0",
              "pendingQuantity"=>"#{count_on_hold}",
              "availableQuantity"=>"#{first_stock_item.count_on_hand}",
              "backorderedQuantity"=>"0"
            }
          ]

          expect{subject.update_inventory(response)}.to change{variant.stock_items.first.count_on_hold}.to(count_on_hold)
        end

        it "should change count_on_hold on data from NG" do
          first_stock_item = variant.stock_items.first
          count_on_hand = first_stock_item.count_on_hand + random.rand(100) + 1
          response = [
            {
              "id"=>"1148187",
              "sku"=>"1234",
              "currentQuantity"=>"6",
              "receivingQuantity"=>"0",
              "arrivedPutAwayQuantity"=>"0",
              "kittingQuantity"=>"0",
              "returnsQuantity"=>"0",
              "pendingQuantity"=>"#{first_stock_item.count_on_hold}",
              "availableQuantity"=>"#{count_on_hand}",
              "backorderedQuantity"=>"0"
            }
          ]

          expect{subject.update_inventory(response)}.to change{variant.stock_items.first.count_on_hand}.to(count_on_hand)
        end
      end

      context "there are not sync'ed orders" do
        # BEWARE: fragile tests here

        let(:order) { create :order_with_line_items, state: 'complete', posted_to_newgistics: false }
        let(:variant) { create :variant, sku: '1234' }

        before :each do
          # prepare order
          first_line_item = order.line_items.first
          first_line_item.variant_id = variant.id
          first_line_item.save

          first_line_item_variant = first_line_item.variant_id
          first_line_item_qty = first_line_item.quantity

          # prepare variant
          first_stock_item = variant.stock_items.first
          first_stock_item.stock_location_id = 1 # replace when we will have different stock_location_id's
          first_stock_item.save

          count_on_hand = 100
          count_on_hold = 0

          @response = [
            {
              "id"=>"#{first_line_item_variant}",
              "sku"=>"1234",
              "currentQuantity"=>"6",
              "receivingQuantity"=>"0",
              "arrivedPutAwayQuantity"=>"0",
              "kittingQuantity"=>"0",
              "returnsQuantity"=>"0",
              "pendingQuantity"=>"#{count_on_hold}",
              "availableQuantity"=>"#{count_on_hand}",
              "backorderedQuantity"=>"0"
            }
          ]

          @new_count_on_hand = count_on_hand - first_line_item_qty
          @new_count_on_hold = count_on_hold + first_line_item_qty
        end

        it "should do reconciliation on count_on_hand" do
          expect{subject.update_inventory(@response)}.to change{variant.stock_items.first.count_on_hand}.to(@new_count_on_hand)
        end

        it "should do reconciliation on count_on_hold" do
          expect{subject.update_inventory(@response)}.to change{variant.stock_items.first.count_on_hold}.to(@new_count_on_hold)
        end
      end
    end
  end

  describe "#different_inventory_levels?" do

    let(:stock_item) { Spree::StockItem.new }
    let(:random) { Random.new }

    it "must return true if levels of count_on_hold are different" do
      stock_item.instance_eval{ count_on_hold = 10 }
      stock_item.instance_eval{ count_on_hand = 15 }
      difference = random.rand(100) + 1
      count_on_hold = stock_item.count_on_hold + difference
      expect(subject.different_inventory_levels?(stock_item, count_on_hold, stock_item.count_on_hand)).to be_truthy
    end

    it "must return true if levels of count_on_hand are different" do
      stock_item.instance_eval{ count_on_hold = 10 }
      stock_item.instance_eval{ count_on_hand = 15 }
      difference = random.rand(100) + 1
      count_on_hand = stock_item.count_on_hand + difference
      expect(subject.different_inventory_levels?(stock_item, stock_item.count_on_hold, count_on_hand)).to be_truthy
    end

    it "must return false if all levels are equal" do
      stock_item.instance_eval{ count_on_hold = 10 }
      stock_item.instance_eval{ count_on_hand = 15 }
      expect(subject.different_inventory_levels?(stock_item, stock_item.count_on_hold, stock_item.count_on_hand)).to be_falsy
    end
  end
end
