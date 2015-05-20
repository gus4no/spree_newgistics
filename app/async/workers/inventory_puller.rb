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
      # preload line_items of unsynced orders
      unsynced_line_items = Spree::Order.not_in_newgistics.collect { |os| os.line_items }.flatten

      newgistics_stock_items.each do |newgistic_stock_item|
        variant = Spree::Variant.where(is_master: false).find_by(sku: newgistic_stock_item["sku"])
        next unless variant
        ## Since newgistics is the only stock location, set 1 as stock_location id.
        ## TODO: add support for multiple stock locations.
        stock_item = variant.stock_items.find_by(stock_location_id: 1)
        ng_pending_quantity = newgistic_stock_item['pendingQuantity'].to_i
        ng_available_quantity = newgistic_stock_item['availableQuantity'].to_i

        if stock_item
          if (stock_item.count_on_hold != ng_pending_quantity || stock_item.count_on_hand != ng_available_quantity)
            # check if variant is used in not synced orders
            unsynced_on_hold = 0

            unsynced_line_items.each do |li|
              if li.variant_id == variant.id
                unsynced_on_hold += li.quantity
              end
            end

            puts "Not synced #{variant.sku}"
            puts "On hold - spree: #{stock_item.count_on_hold} NG: #{ng_pending_quantity}"
            puts "Avaliable - spree: #{stock_item.count_on_hand} NG: #{ng_available_quantity}"
            puts "Variant is used #{unsynced_on_hold} times in unsynced orders"

            stock_item.update_columns(
              count_on_hold: (ng_pending_quantity + unsynced_on_hold),
              count_on_hand: (ng_available_quantity - unsynced_on_hold)
            )

            variant.touch
          end
        end
      end
    end
  end
end
