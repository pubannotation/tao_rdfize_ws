#!/usr/bin/env ruby
require 'sinatra/base'
require 'json'
require 'tao_rdfizer'

class TAORDFizerWS < Sinatra::Base
	before do
		@annotations = if request.content_type && request.content_type.downcase == 'application/json'
			body = request.body.read
			unless body.empty?
				JSON.parse body, :symbolize_names => true
			end
		end
	end

	get '/' do
		erb :index
	end

	post '/' do
		mode = params[:mode]
		mode = mode.to_sym unless mode.nil?

		begin
			raise ArgumentError, "No annotations found. Please supply annotations in the PubAnnotation JSON format in the body of your post request." if @annotations.nil? || @annotations.empty?
			ttl = TAO::tao_rdfizer(@annotations, mode)

			headers \
				'Content-Type' => 'application/x-turtle; charset=utf-8'
			ttl
		rescue ArgumentError, IOError => e
			status 406
			e.message + "\n"
		end
	end
end
