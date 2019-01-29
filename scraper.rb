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

  field :area_id do
    json[:siglaUf]
  end

  field :image do
    json[:urlFoto]
  end

  field :source do
    json[:uri]
  end
end

class FullMember < Scraped::JSON
  field :fullname do
    data[:nomeCivil]
  end

  field :gender do
    data[:sexo]
  end

  field :twitter do
    social.find { |link| link.include? 'twitter.com' }
  end

  field :facebook do
    social.find { |link| link.include? 'facebook.com' }
  end

  field :birthdate do
    data[:dataNascimento]
  end

  field :deathdate do
    data[:dataFalecimento]
  end

  field :email do
    data.dig(:ultimoStatus, :gabinet, :email)
  end

  field :status do
    data.dig(:ultimoStatus, :situacao)
  end

  field :finalterm do
    data.dig(:ultimoStatus, :idLegislatura)
  end

  field :end_date do
    return if status == "Exercício"
    data.dig(:ultimoStatus, :data)
  end

  private

  def data
    json[:dados]
  end

  def social
    data[:redeSocial]
  end
end

def response(url)
  Scraped::Request.new(url: url, headers: { 'Accept' => 'application/json' }).response
end

TERMS = 54 .. 55

data = TERMS.flat_map do |term|
  url = 'https://dadosabertos.camara.leg.br/api/v2/deputados?idLegislatura=%d&ordem=ASC&ordenarPor=nome&itens=100' % term
  members = []

  while (url)
    page = MemberList.new(response: response(url))
    members += page.members
    url = page.next
  end

  members.map do |mem|
    mem.merge(FullMember.new(response: response(mem[:source])).to_h).merge(term: term)
  end
end

data.each { |mem| puts mem.reject { |_, v| v.to_s.empty? }.sort_by { |k, _| k }.to_h } if ENV['MORPH_DEBUG']

ScraperWiki.sqliteexecute('DROP TABLE data') rescue nil
ScraperWiki.save_sqlite(%i[id], data)
