Spree::Variant.class_eval do

  after_create :post_to_newgistics, unless: lambda { |v| v.is_master? && !Rails.env.production? }
  after_update :post_to_newgistics, unless: lambda { |v| v.is_master? && !Rails.env.production? }

  scope :not_in_newgistics, -> { where(posted_to_newgistics: false, is_master: false) }


  def newgistics_class
    shipping_category.name == 'Hazardous' ? 'ORM-D' : ''
  end

  ## This method posts the new variant to newgistics, if it success, it updates the
  ## posted_to_newgistics flag in the variant for further queue updates control.
  def post_to_newgistics
      document = Spree::Newgistics::DocumentBuilder.build_product([self])
      response = Spree::Newgistics::HTTPManager.post('/post_products.aspx', document)

      if response.status == 200
        errors = Nokogiri::XML(response.body).css('errors').children.any?
        update_column(:posted_to_newgistics, true) unless errors
      end
  end
end
