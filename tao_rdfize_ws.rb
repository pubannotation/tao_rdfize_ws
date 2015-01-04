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

		# get necessary URIs
		@project_uri = @params[:project]
		@text_uri    = @params[:target]

		@source_db, @source_id, @div_id = get_target_info(@text_uri)
		@text_id = @div_id.nil? ? "#{@source_db}-#{@source_id}" : "#{@source_db}-#{@source_id}-#{@div_id}"
		@doc_uri = doc_uri(@source_db, @source_id)

		# namespaces
		@namespaces = {}
		@namespaces['prj'] = @project_uri + '/'
		@params[:namespaces].each {|n| @namespaces[n[:prefix]] = n[:uri]} unless @params[:namespaces].nil?

		# annotations
		@text    	   = @params[:text]
		@denotations = @params[:denotations]
		@denotations = [] if @denotations.nil?

		# denotations preprocessing
		@denotations.each do |d|
			d[:uri] = "prj:#{@text_id}-#{d[:id]}"
			d[:obj] = 'SYM' if d[:obj].match(/\W/)
		end

		# collect spans
		spanh = {}
		@denotations.each do |d|
			span_uri = "<#{@text_uri}/spans/#{d[:span][:begin]}-#{d[:span][:end]}>"
			d[:span_uri] = span_uri

			if spanh[span_uri].nil?
				spanh[span_uri] = {:uri => span_uri, :text => @text_uri, :begin => d[:span][:begin], :end => d[:span][:end], :denotations => [d]}
			else
				spanh[span_uri][:denotations] << d
			end
		end
		@spans = spanh.values
		@spans.sort!{|a, b| a[:begin] <=> a[:begin] || a[:end] <=> a[:end]}

		len = @text.length
		num = @spans.length

		# initilaize the index
		(0 ... num).each do |i|
			@spans[i][:followings] = []
			@spans[i][:precedings] = []
			@spans[i][:children] = []
		end

		@denotations.each do |d|
			d[:followings] = []
			d[:precedings] = []
			d[:governees] = []
		end

		# index
		(0 ... num).each do |i|
			# find the following position
			fp = @spans[i][:end]
			fp += 1 while fp < len && @text[fp].match(/\s/)
			next if fp == len

			# terminal spans: spans with no embeddings
			if (i == num - 1) || (@spans[i + 1][:begin] >= @spans[i][:end])
				@spans[i][:denotations].each do |d|
					d[:governees] << @spans[i]
					@spans[i][:governer] = d
				end
			end
	
			# examine from tne next
			j = i + 1

			# index the embedded spans
			while j < num && @spans[j][:begin] < @spans[i][:end]
				unless include_parent?(@spans[i][:children], @spans[j])
					@spans[i][:children] << @spans[j]
					@spans[j][:parent] = @spans[i]
				end
				j += 1
			end

			# index the following spans
			while j < num && @spans[j][:begin] == fp do
				@spans[i][:followings] << @spans[j]
				@spans[j][:precedings] << @spans[i]
				j += 1
			end 
		end

		## expand the relations to denotations
		@denotations.each do |d|

			spanh[d[:span_uri]][:followings].each do |fs|
				d[:followings] << fs
				fs[:precedings] << d
				fs[:denotations].each do |fd|
					d[:followings] << fd
					fd[:precedings] << d
				end
			end

			spanh[d[:span_uri]][:precedings].each do |ps|
				d[:precedings] << ps
				ps[:followings] << d
			end

			spanh[d[:span_uri]][:children].each do |cs|
				cs[:denotations].each do |cd|
					d[:governees] << cd
					cd[:governer] = d
				end
			end
		end

		headers \
			'Content-Type' => 'application/x-turtle'
		erb :tao_rdf, :trim => '-'
	end

	def include_parent?(spans, span)
		# spans.each{|s| return true if (s[:begin] <= span[:begin] && s[:end] > span[:end]) || (s[:begin] < span[:begin] && s[:end] >= span[:end])}
		spans.each{|s| return true if s[:begin] <= span[:begin] && s[:end] >= span[:end]}
		return false
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
