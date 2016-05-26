class Order
  def request_from_tib

    case config.order_prefix
    when 'PROD'
      tib_prefix = 0
    when 'STAGING'
      tib_prefix = 1
    when 'UNSTABLE'
      tib_prefix = 2
    when 'TEST'
      tib_prefix = 3
    end

    logger.debug "------------ Prefix = #{config.order_prefix}"
    logger.debug "------------ tib_prefix = #{tib_prefix}"

    request = current_request
    SendIt.tib_request self, {

      :not_available_link => @path_controller.order_url(self),
      :order_id => "#{tib_prefix}#{'%09d' % self.id}",
      :from => config.tib.from_mail,
      :to => config.tib.order_mail
    }

    request.external_number = self.id
    request.order_status = OrderStatus.find_by_code("request")
    request.save!
    save!

  end
end
