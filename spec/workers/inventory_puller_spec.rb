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
end
