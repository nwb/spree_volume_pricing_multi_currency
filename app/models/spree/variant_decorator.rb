Spree::Variant.class_eval do

  def join_volume_prices(user=nil, currency=nil)
    table = Spree::VolumePrice.arel_table
    #currency ||= Spree::Config[:currency]
    if user
      Spree::VolumePrice.where(
        (table[:variant_id].eq(self.id)
          .or(table[:volume_price_model_id].in(self.volume_price_models.ids)))
          .and(table[:role_id].eq(user.resolve_role).or(table[:role_id].eq(nil)))
            .and(table[:currency].eq(currency))
        )
        .order(position: :asc)
    else
      Spree::VolumePrice.where(
        (table[:variant_id]
          .eq(self.id)
          .or(table[:volume_price_model_id].in(self.volume_price_models.ids)))
          .and(table[:role_id].eq(nil))
            .and(table[:currency].eq(currency))
        ).order(position: :asc)
    end
  end

  # calculates the price based on quantity
  def volume_price(quantity, user=nil, currency=nil)
    compute_volume_price_quantities :volume_price, self.price, quantity, user, currency
  end

  # return percent of earning
  def volume_price_earning_percent(quantity, user=nil, currency=nil)
    compute_volume_price_quantities :volume_price_earning_percent, 0, quantity, user, currency
  end

  # return amount of earning
  def volume_price_earning_amount(quantity, user=nil, currency=nil)
    compute_volume_price_quantities :volume_price_earning_amount, 0, quantity, user, currency
  end

  protected

  def use_master_variant_volume_pricing?
    Spree::Config.use_master_variant_volume_pricing && !(self.product.master.join_volume_prices.count == 0)
  end

  def compute_volume_price_quantities type, default_price, quantity, user, currency
    volume_prices = self.join_volume_prices user, currency
    if volume_prices.count == 0
      if use_master_variant_volume_pricing?
        self.product.master.send(type, quantity, user)
      else
        return default_price
      end
    else
      volume_prices.each do |volume_price|
        if volume_price.include?(quantity)
          return self.send "compute_#{type}".to_sym, volume_price
        end
      end

      # No price ranges matched.
      default_price
    end
  end

  def compute_volume_price volume_price
    case volume_price.discount_type
    when 'price'
      return volume_price.amount
    when 'dollar'
      return self.price - volume_price.amount
    when 'percent'
      return self.price * (1 - volume_price.amount)
    end
  end

  def compute_volume_price_earning_percent volume_price
    case volume_price.discount_type
    when 'price'
      diff = self.price - volume_price.amount
      return (diff * 100 / self.price).round
    when 'dollar'
      return (volume_price.amount * 100 / self.price).round
    when 'percent'
      return (volume_price.amount * 100).round
    end
  end

  def compute_volume_price_earning_amount volume_price
    case volume_price.discount_type
    when 'price'
      return self.price - volume_price.amount
    when 'dollar'
      return volume_price.amount
    when 'percent'
      return self.price - (self.price * (1 - volume_price.amount))
    end
  end
end
