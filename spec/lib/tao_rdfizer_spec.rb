require 'spec_helper'

describe TAO do
	describe "::tao_rdfizer" do
		context 'for a normal iput without _base' do
			it 'should produce a valid TTL representation' do
				@annotations = {
					project:"project_name",
					target:"http://pubannotation.org/docs/sourcedb/PubMed/sourceid/10022435",
					text:"example text",
					denotations:[
						{id:"T1", span:{begin:0,end:7},obj:"obj1"},
						{id:"T2", span:{begin:8,end:12},obj:"!!"},
						{id:"T3", span:{begin:0,end:12},obj:"-COMMA-"}
					],
					relations:[
						{id:"R1", subj:"T1", pred:"associatedWith", obj:"T2"}
					],
				}
				expect(TAO::tao_rdfizer(@annotations)).to eq('')
			end
		end
		context 'for a normal iput with _base' do
			it 'should produce a valid TTL representation' do
				@annotations = {
					project:"project_name",
					target:"http://pubannotation.org/docs/sourcedb/PubMed/sourceid/10022435",
					text:"example text",
					denotations:[
						{id:"T1", span:{begin:0,end:7},obj:"obj1"},
						{id:"T2", span:{begin:8,end:12},obj:"!!"},
						{id:"T3", span:{begin:0,end:12},obj:"-COMMA-"}
					],
					relations:[
						{id:"R1", subj:"T1", pred:"associatedWith", obj:"T2"}
					],
					namespaces:[
						{prefix:"_base", uri:"http://example.org/namespace/"}
					]
				}
				expect(TAO::tao_rdfizer(@annotations)).to eq('')
			end
		end
	end
end