module Workers
  class InventoryPuller < AsyncBase
    include Sidekiq::Worker
    include Alerts

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
      unsynced_line_items = Spree::Order.not_in_newgistics.includes(:line_items).collect { |os| os.line_items }.flatten

      log = File.open("#{Rails.root}/log/#{self.jid}_newgistics_inventory_import.log", 'a')
      log << "Starting inventory sync process: #{Time.now}\n\n"

      skus = newgistics_stock_items.map { |si| si["sku"] }
      variants = Spree::Variant.where(sku: skus, is_master: false).includes(:stock_items)

      newgistics_stock_items.each do |newgistic_stock_item|
        variant = variants.find { |v| v.sku == newgistic_stock_item["sku"] }
        next unless variant
        ## Since newgistics is the only stock location, set 1 as stock_location id.
        ## TODO: add support for multiple stock locations.
        stock_item = variant.stock_items.find { |si| si.stock_location_id == 1 }
        ng_pending_quantity = newgistic_stock_item['pendingQuantity'].to_i
        ng_available_quantity = newgistic_stock_item['availableQuantity'].to_i

        if stock_item && different_inventory_levels?(stock_item, ng_pending_quantity, ng_available_quantity)
          # check if variant is used in not synced orders
          unsynced_on_hold = 0

          unsynced_line_items.each do |li|
            if li.variant_id == variant.id
              unsynced_on_hold += li.quantity
            end
          end

          log << "Not synced #{newgistic_stock_item['sku']}\n"
          log << "On hold - spree: #{stock_item.count_on_hold} NG: #{ng_pending_quantity}\n"
          log << "Avaliable - spree: #{stock_item.count_on_hand} NG: #{ng_available_quantity}\n"
          log << "Variant is used #{unsynced_on_hold} times in unsynced orders\n"

          if ng_available_quantity < 0 or stock_item.count_on_hand < 0
            msg = %Q(Quantity of available items for SKU #{newgistic_stock_item['sku']} becomes negative.
            spree: #{stock_item.count_on_hand},
            NG: #{ng_available_quantity}")
            unless slack_notify(msg) 
              log << "CRITICAL: Can't send slack notification, please check settings\n"
            end
          end

          stock_item.update_columns(
            count_on_hold: (ng_pending_quantity + unsynced_on_hold),
            count_on_hand: (ng_available_quantity - unsynced_on_hold)
          )

          variant.touch
        end
      end

      log.close
    end

    def different_inventory_levels?(stock_item, ng_pending_quantity, ng_available_quantity)
      stock_item.count_on_hold != ng_pending_quantity ||
      stock_item.count_on_hand != ng_available_quantity
    end
  end
end
