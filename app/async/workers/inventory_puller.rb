module Workers
  class InventoryPuller < AsyncBase
    include Sidekiq::Worker

    def perform

      response = Spree::Newgistics::HTTPManager.get('inventory.aspx')
      if response.status == 200
        xml = Nokogiri::XML(response.body).to_xml
        stock_items = Hash.from_xml(xml)["response"]["products"]
        if stock_items
          update_inventory(stock_items.values.flatten)
        end
      end
    end

    def update_inventory(newgistics_stock_items)
      newgistics_stock_items.each do |newgistic_stock_item|
        variant = Spree::Variant.where(is_master: false).find_by(sku: newgistic_stock_item["sku"])
        next unless variant
        ## Since newgistics is the only stock location, set 1 as stock_location id.
        ## TODO: add support for multiple stock locations.
        stock_item = variant.stock_items.find_by(stock_location_id: 1)
        if stock_item
          stock_item.update_column(:count_on_hold, newgistic_stock_item['pendingQuantity'].to_i)
          stock_item.update_column(:count_on_hand, newgistic_stock_item['availableQuantity'].to_i)
          variant.touch
        end
      end
    end
  end
end
