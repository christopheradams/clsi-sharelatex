SandboxedModule = require('sandboxed-module')
sinon = require('sinon')
require('chai').should()
modulePath = require('path').join __dirname, '../../../app/js/CompileController'
tk = require("timekeeper")

describe "CompileController", ->
	beforeEach ->
		@CompileController = SandboxedModule.require modulePath, requires:
			"./CompileManager": @CompileManager = {}
			"./RequestParser": @RequestParser = {}
			"settings-sharelatex": @Settings =
				apis:
					clsi:
						url: "http://clsi.example.com"
			"./ProjectPersistenceManager": @ProjectPersistenceManager = {}
			"logger-sharelatex": @logger = { log: sinon.stub(), error: sinon.stub() }
		@Settings.externalUrl = "http://www.example.com"
		@req = {}
		@res = {}

	describe "compile", ->
		beforeEach ->
			@req.body = {
				compile: "mock-body"
			}
			@req.params =
				project_id: @project_id = "project-id-123"
			@request = {
				compile: "mock-parsed-request"
			}
			@request_with_project_id =
				compile: @request.compile
				project_id: @project_id
			@output_files = [{
				path: "output.pdf"
				type: "pdf"
			}, {
				path: "output.log"
				type: "log"
			}]
			@RequestParser.parse = sinon.stub().callsArgWith(1, null, @request)
			@ProjectPersistenceManager.markProjectAsJustAccessed = sinon.stub().callsArg(1)
			@res.send = sinon.stub()

		describe "successfully", ->
			beforeEach ->
				@CompileManager.doCompile = sinon.stub().callsArgWith(1, null, @output_files)
				@CompileController.compile @req, @res

			it "should parse the request", ->
				@RequestParser.parse
					.calledWith(@req.body)
					.should.equal true

			it "should run the compile for the specified project", ->
				@CompileManager.doCompile
					.calledWith(@request_with_project_id)
					.should.equal true

			it "should mark the project as accessed", ->
				@ProjectPersistenceManager.markProjectAsJustAccessed
					.calledWith(@project_id)
					.should.equal true

			it "should return the JSON response", ->
				@res.send
					.calledWith(JSON.stringify
						compile:
							status: "success"
							error: null
							outputFiles: @output_files.map (file) =>
								url: "#{@Settings.apis.clsi.url}/project/#{@project_id}/output/#{file.path}"
								type: file.type
					)
					.should.equal true
			
		describe "with an error", ->
			beforeEach ->
				@CompileManager.doCompile = sinon.stub().callsArgWith(1, new Error(@message = "error message"), null)
				@CompileController.compile @req, @res
		
			it "should return the JSON response with the error", ->
				@res.send
					.calledWith(JSON.stringify
						compile:
							status: "failure"
							error:  @message
							outputFiles: []
					)
					.should.equal true

