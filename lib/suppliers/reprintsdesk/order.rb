class Order
  def request_from_reprintsdesk
    client = Savon.client(
      wsdl: config.reprintsdesk.wsdl,
      env_namespace: :soap,
      soap_version: 1,
      soap_header: {
        'UserCredentials' => {
          'UserName' => config.reprintsdesk.user,
          'Password' => config.reprintsdesk.password,
        },
        :attributes! => { 'UserCredentials' => { 'xmlns' => "http://reprintsdesk.com/webservices/" }},
      }
    )
    Savon.observers << SavonObserver.new if Rails.env.development?

    request = current_request
    response = client.call(:order_get_price_estimate,
      message: { issn: issn || eissn, year: date, totalpages: 1 },
      :attributes => { "xmlns" => "http://reprintsdesk.com/webservices/" })
    if response.body[:order_get_price_estimate_response][:order_get_price_estimate_result] == "1"
      request.external_service_charge = response.body[:order_get_price_estimate_response][:xml_data][:estimate][:servicecharge]
      request.external_copyright_charge = response.body[:order_get_price_estimate_response][:xml_data][:estimate][:copyrightcharge]
      request.external_currency = 'USD'
    end

    builder = Nokogiri::XML::Builder.new do |xml|
      xml.xmlNode {
        xml.order('xmlns' => '') {
          xml.orderdetail {
          xml.ordertypeid "4"
            xml.deliverymethodid "5"
            xml.comment_ ""
            xml.aulast aulast
            xml.aufirst aufirst
            xml.issn issn
            xml.eissn eissn
            xml.isbn isbn
            xml.title title
            xml.atitle atitle
            xml.volume volume
            xml.issue issue
            xml.spage spage
            xml.epage epage
            xml.pages pages
            xml.date date
          }
          xml.user {
            xml.username config.reprintsdesk.username
            xml.email config.reprintsdesk.systemmail
            xml.firstname config.reprintsdesk.firstname
            xml.lastname config.reprintsdesk.lastname
            xml.billingreference id
          }
          xml.deliveryprofile {
            xml.firstname config.reprintsdesk.firstname
            xml.lastname config.reprintsdesk.lastname
            xml.companyname config.reprintsdesk.companyname
            xml.address1 config.reprintsdesk.address1
            xml.address2 config.reprintsdesk.address2
            xml.city config.reprintsdesk.city
            xml.zip config.reprintsdesk.zipcode
            xml.statecode config.reprintsdesk.statecode
            xml.statename config.reprintsdesk.statename
            xml.countrycode config.reprintsdesk.countrycode
            xml.phone config.reprintsdesk.phone
            xml.fax config.reprintsdesk.fax
            xml.email email
          }
          xml.processinginstructions {
            xml.processinginstruction('id' => '1', 'valueid' => '1')
            xml.processinginstruction('id' => '2', 'valueid' => '0')
          }
          xml.customerreferences {
            xml.customerreference(config.reprintsdesk.order_prefix + "-#{id}", 'id' => '1')
            xml.customerreference('OTHER', 'id' => '2')
          }
        }
      }
    end

    response = client.call(:order_place_order2,
      message: builder.to_xml(:save_with => Nokogiri::XML::Node::SaveOptions::NO_DECLARATION),
      attributes: { "xmlns" => "http://reprintsdesk.com/webservices/" })
    if response.body[:order_place_order2_response][:order_place_order2_result] == "1"
      request.external_id = response.body[:order_place_order2_response][:order_id]
      request.order_status = OrderStatus.find_by_code("requested")
    end
    request.save!
    save!
  end
end