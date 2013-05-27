# coding: utf-8

require 'uri'
require 'net/http'

class GoogleSuggest

  def initialize
    @api = api
  end

  def get_xml(keyword)
    res = get_response '/complete/search', {
      output: 'toolbar',
      hl: 'ja',
      q: URI.encode(keyword)
    }

    res.body.to_s
  end

  def count_for(keyword)
    doc = get_xml keyword

    search = 'num_queries int="'
    index = doc.index search

    return 0 unless index

    index += search.length
    stop = doc.index '"', index

    doc[index..stop].to_i
  end

private

  GOOGLE_HOST = 'www.google.com'

  def api
    Net::HTTP.new GOOGLE_HOST
  end

  def get_response(path, query)
    path << '?' << query.map{ |k, v| "#{k}=#{v}" }.join('&')
    req = Net::HTTP::Get.new path
    @api.request req
  end

end

