#!/bin/env ruby

require 'json'
require 'net/http'

host=ARGV[0]
user=ARGV[1]
password=ARGV[2]

uri = URI.parse("http://#{host}/users/#{user}/tokens")
http = Net::HTTP.new(uri.host, uri.port)
request = Net::HTTP::Post.new(uri.request_uri)
request.body = "{\"password\":\"#{password}\"}"
response = http.request(request)
token = JSON.load(response.body)['token']

File.write(ENV['HOME'] + '/.tsuru_token', token)