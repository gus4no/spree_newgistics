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
        ng_pending_quantity = newgistic_stock_item['pendingQuantity'].to_i
        ng_available_quantity = newgistic_stock_item['availableQuantity'].to_i
        if stock_item
          # check if variant is used in not synced orders
          unsynced_on_hold = 0
          not_in_ng = Spree::Order.not_in_newgistics
          not_in_ng.each do |order|
            order.line_items.each do |li|
              if li.variant_id == variant.id
                unsynced_on_hold += li.quantity
              end
            end
          end

          if (stock_item.count_on_hold != ng_pending_quantity)
            puts "Not synced #{variant.sku} - spree: #{stock_item.count_on_hold} NG: #{ng_pending_quantity}"
            puts "Variant is used #{unsynced_on_hold} times in unsynced orders"
            stock_item.update_column(:count_on_hold, ng_pending_quantity + unsynced_on_hold)
          end

          if (stock_item.count_on_hand != ng_available_quantity)
            puts "Not synced #{variant.sku} - #{stock_item.count_on_hand} NG: #{ng_available_quantity}"
            puts "Variant is used #{unsynced_on_hold} times in unsynced orders"
            stock_item.update_column(:count_on_hand, ng_available_quantity - unsynced_on_hold)
          end

          variant.touch
        end
      end
    end
  end
end
