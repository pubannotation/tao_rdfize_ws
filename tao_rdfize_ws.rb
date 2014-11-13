#!/usr/bin/env ruby
require 'sinatra/base'
require 'json'
require 'erb'

class TAORDFizeWS < Sinatra::Base

	before do
		@params = JSON.parse request.body.read, :symbolize_names => true if request.content_type && request.content_type.downcase == 'application/json'
	end

	get '/' do
		erb :index
	end

	post '/' do
		@params      = @params[:annotation] if @params && @params.has_key?(:annotation)
		@text    	   = @params[:text]
		@denotations = @params[:denotations]
		@project_uri = @params[:project]
		@text_uri    = @params[:target]
		# @namespaces  = @params[:namespaces].to_h
		namespaces  = @params[:namespaces]
		@ns = {}
		namespaces.each {|n| @ns[n[:prefix]] = n[:uri]} unless namespaces.nil?

		@source_db, @source_id, @div_id = get_target_info(@text_uri)
		@text_id = @div_id.nil? ? "#{@source_db}-#{@source_id}" : "#{@source_db}-#{@source_id}-#{@div_id}"
		@doc_uri = doc_uri(@source_db, @source_id)

		headers \
			'Content-Type' => 'application/x-turtle'
		erb :tao_rdf, :trim => '-'
	end

	def doc_uri (sourcedb, sourceid)
		case sourcedb
		when 'PubMed'
			'http://www.ncbi.nlm.nih.gov/pubmed/' + sourceid
		when 'PMC'
			'http://www.ncbi.nlm.nih.gov/pmc/' + sourceid
		else
			nil
		end
	end

	def get_target_info (text_uri)
		source_db = (text_uri =~ %r|/sourcedb/([^/]+)|)? $1 : nil
		source_id = (text_uri =~ %r|/sourceid/([^/]+)|)? $1 : nil
		div_id    = (text_uri =~ %r|/divs/([^/]+)|)? $1 : nil

		return source_db, source_id, div_id
	end
end
