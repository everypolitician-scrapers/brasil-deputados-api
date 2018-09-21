#!/bin/env ruby
# encoding: utf-8
# frozen_string_literal: true

require 'json'
require 'nokogiri'
require 'pry'
require 'scraped'
require 'scraperwiki'

require 'open-uri/cached'
OpenURI::Cache.cache_path = '.cache'

class MemberList < Scraped::JSON
  field :members do
    json[:dados].map { |m| fragment(m => Member).to_h }
  end

  field :next do
    return unless next_link
    next_link[:href]
  end

  private

  def next_link
    json[:links].find { |l| l[:rel] == 'next' }
  end
end

class Member < Scraped::JSON
  field :id do
    json[:id]
  end

  field :name do
    json[:nome]
  end

  field :party_id do
    json[:siglaPartido]
  end

  field :party_info do
    json[:uriPartido]
  end

  field :area_id do
    json[:siglaUf]
  end

  field :image do
    json[:urlFoto]
  end
end

class FullMember < Scraped::JSON
  field :fullname do
    json[:nomeCivil]
  end

  field :twitter do
    binding.pry if json[:id] == 74752
  end
end

def response(url)
  Scraped::Request.new(url: url, headers: { 'Accept' => 'application/json' }).response
end

url = 'https://dadosabertos.camara.leg.br/api/v2/deputados?idLegislatura=55&ordem=ASC&ordenarPor=nome&itens=100'
data = []

while (url)
  warn url
  page = MemberList.new(response: response(url))
  data += page.members
  url = page.next
end

data.each { |mem| puts mem.reject { |_, v| v.to_s.empty? }.sort_by { |k, _| k }.to_h } if ENV['MORPH_DEBUG']

ScraperWiki.sqliteexecute('DROP TABLE data') rescue nil
ScraperWiki.save_sqlite(%i[id], data)
