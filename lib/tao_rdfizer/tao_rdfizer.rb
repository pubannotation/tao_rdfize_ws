#!/usr/bin/env ruby
require 'erb'

module TAO; end unless defined? TAO

class << TAO
  # if mode == :spans then produces span descriptions
  # if mode == :annotations then produces annotation descriptions
  # if mode == nil then produces both
	def tao_rdfizer(annotations, mode = nil)
		missing_elements = []
		missing_elements << 'project' if !annotations.has_key?(:project) && (mode.nil? || mode == :annotations)
		missing_elements << 'target'  unless annotations.has_key?(:target)
		missing_elements << 'text'    unless annotations.has_key?(:text)
		raise ArgumentError, "Cannot find some required information: #{missing_elements.join(', ')}." unless missing_elements.empty?

		template_filename = unless mode.nil?
			if mode == :annotations
				'views/tao_annotations_ttl.erb'
			elsif mode == :spans
				'views/tao_spans_ttl.erb'
			else
				'views/tao_ttl.erb'
			end
		else
			'views/tao_ttl.erb'
		end

		tao_ttl_template = File.read(template_filename)
		tao_ttl_erb = ERB.new(tao_ttl_template, nil, '-')

		# get necessary URIs
		project_uri = 'http://pubannotation.org/projects/' + annotations[:project] unless mode ==:spans
		text_uri    = annotations[:target]
		source_db, source_id, div_id = get_target_info(text_uri)
		text_id = div_id.nil? ? "#{source_db}-#{source_id}" : "#{source_db}-#{source_id}-#{div_id}"

		# namespaces
		namespaces = {}
		annotations[:namespaces].each {|n| namespaces[n[:prefix]] = n[:uri]} unless annotations[:namespaces].nil?
		raise ArgumentError, "'prj' is a reserved prefix." if namespaces.has_key?('prj')
		namespaces['prj'] = project_uri + '/' unless mode ==:spans

		text = annotations[:text]

		# denotations
		denotations = annotations[:denotations]
		denotations = [] if denotations.nil?

		if mode == :spans && annotations.has_key?(:tracks)
			annotations[:tracks].each {|track| denotations += track[:denotations]}
		end

		# denotations preprocessing
		denotations.each do |d|
			d[:obj_uri] = "prj:#{text_id}-#{d[:id]}"
			d[:cls_uri] = find_uri(d[:obj], namespaces)
		end

		# collect spans
		spanh = {}
		denotations.each do |d|
			span_uri = "<#{text_uri}/spans/#{d[:span][:begin]}-#{d[:span][:end]}>"
			d[:span_uri] = span_uri

			if spanh[span_uri].nil?
				spanh[span_uri] = {:span_uri => span_uri, :source_uri => text_uri, :begin => d[:span][:begin], :end => d[:span][:end], :denotations => [d]}
			else
				spanh[span_uri][:denotations] << d
			end
		end
		spans = spanh.values
		spans.sort!{|a, b| (a[:begin] <=> b[:begin]).nonzero? || b[:end] <=> a[:end]}

		## begin indexing
		len = text.length
		num = spans.length

		# initilaize the index
		(0 ... num).each do |i|
			spans[i][:followings] = []
			spans[i][:precedings] = []
			spans[i][:children] = []
		end

		(0 ... num).each do |i|
			# index the embedded spans
			j = i + 1
			while j < num && spans[j][:begin] < spans[i][:end]
				unless include_parent?(spans[i][:children], spans[j])
					spans[i][:children] << spans[j]
					spans[j][:parent] = spans[i]
				end
				j += 1
			end

			# find the following position
			fp = spans[i][:end]
			fp += 1 while fp < len && text[fp].match(/\s/)
			next if fp == len

			# index the following spans
			while j < num && spans[j][:begin] == fp
				spans[i][:followings] << spans[j]
				spans[j][:precedings] << spans[i]
				j += 1
			end 
		end

		# relations
		relations = annotations[:relations]
		relations = [] if relations.nil?

		# relations preprocessing
		relations.each do |r|
			r[:subj_uri] = "prj:#{text_id}-#{r[:subj]}"
			r[:obj_uri] = "prj:#{text_id}-#{r[:obj]}"
			r[:pred_uri] = find_uri(r[:pred], namespaces)
		end

		ttl = tao_ttl_erb.result binding
	end

	def include_parent?(spans, span)
		# spans.each{|s| return true if (s[:begin] <= span[:begin] && s[:end] > span[:end]) || (s[:begin] < span[:begin] && s[:end] >= span[:end])}
		spans.each{|s| return true if s[:begin] <= span[:begin] && s[:end] >= span[:end]}
		return false
	end

	def get_target_info (text_uri)
		source_db = (text_uri =~ %r|/sourcedb/([^/]+)|)? $1 : nil
		source_id = (text_uri =~ %r|/sourceid/([^/]+)|)? $1 : nil
		div_id    = (text_uri =~ %r|/divs/([^/]+)|)? $1 : nil

		return source_db, source_id, div_id
	end

	def find_uri (label, namespaces)
		delimiter_position = label.index(':')
		if !delimiter_position.nil? && namespaces.keys.include?(label[0...delimiter_position])
			label
		else
			label = 'SYM' if label.match(/^\W+$/)
			namespaces.has_key?('_base') ? "<##{label}>" : "prj:#{label}"
		end
	end
end

if __FILE__ == $0
  require 'json'
  begin
		annotations = JSON.parse File.read(ARGV[0]), :symbolize_names => true
		mode = ARGV[1]
		mode = mode.to_sym unless mode.nil?
		puts TAO::tao_rdfizer(annotations, mode)
	rescue ArgumentError, IOError => e
		puts e.message
	end
end