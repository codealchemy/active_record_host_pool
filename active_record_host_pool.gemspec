Gem::Specification.new "active_record_host_pool", "0.6.3" do |s|
  s.authors = ["Ben Osheroff"]
  s.date = "2012-06-11"
  s.summary = "Allow ActiveRecord to share a connection to multiple databases on the same host"
  s.description = ""
  s.email = ["ben@gimbo.net"]
  s.extra_rdoc_files = [
    "MIT-LICENSE",
    "Readme.md"
  ]
  s.files = [
    "Readme.md",
    "lib/active_record_host_pool.rb",
    "lib/active_record_host_pool/connection_adapter_mixin.rb",
    "lib/active_record_host_pool/connection_proxy.rb",
    "lib/active_record_host_pool/pool_proxy.rb"
  ]
  s.homepage = "https://github.com/zendesk/active_record_host_pool"
  s.test_files = ["test/database.yml", "test/helper.rb", "test/schema.rb", "test/test_arhp.rb"]
  s.license = "MIT"

  s.add_runtime_dependency("activerecord")

  s.add_development_dependency("rake")
  s.add_development_dependency("shoulda")
  s.add_development_dependency("mysql")
  s.add_development_dependency("mysql2")
  s.add_development_dependency("mocha", "~>0.11.0") # 0.12 removes dots from test output
  s.add_development_dependency("test-unit", ">=2.5.1")
  s.add_development_dependency("appraisal")
  if RUBY_VERSION < "1.9.0"
    s.add_development_dependency("ruby-debug") 
  else
    s.add_development_dependency("debugger")
  end
end

