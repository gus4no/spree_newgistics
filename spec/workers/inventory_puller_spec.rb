require 'spec_helper'

describe Workers::InventoryPuller do
  describe "#update_inventory" do
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
