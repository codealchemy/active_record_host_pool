require 'bundler/setup'
require 'bundler/gem_tasks'
require 'rake/testtask'
require 'bump/tasks'
require 'rubocop/rake_task'

Rake::TestTask.new do |test|
  test.pattern = 'test/test_*.rb'
  test.verbose = true
  test.warning = true
end

task default: ['rubocop', 'test']

RuboCop::RakeTask.new
