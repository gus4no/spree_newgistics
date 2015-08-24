Spree::Variant.class_eval do

  after_save :post_to_newgistics

  scope :not_in_newgistics, -> { where(posted_to_newgistics: false, is_master: false) }


  def newgistics_class
    shipping_category.name == 'Hazardous' ? 'ORM-D' : ''
  end

  ## This method posts the new variant to newgistics, if it success, it updates the
  ## posted_to_newgistics flag in the variant for further queue updates control.
  def post_to_newgistics
    return unless can_post_to_newgistics
    document = Spree::Newgistics::DocumentBuilder.build_product([self])
    response = Spree::Newgistics::HTTPManager.post('/post_products.aspx', document)

    if response.status == 200
      errors = Nokogiri::XML(response.body).css('errors').children.any?
      update_column(:posted_to_newgistics, true) unless errors
    end
  end

  private

  def can_post_to_newgistics
    can_post = (ENV["ENABLE_NEWGISTICS"] && ENV["ENABLE_NEWGISTICS"].downcase == 'true') || !Rails.env.test?
    !is_master? && can_post
  end
end
