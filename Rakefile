# frozen_string_literal: true

require 'bundler/gem_tasks'
require 'rspec/core/rake_task'

RSpec::Core::RakeTask.new(:spec)

task :rubocop do
  sh 'bundle exec rubocop --config .rubocop.yml lib spec Rakefile Gemfile chronicle.gemspec'
end

task quality: %i[rubocop spec]

task default: :spec
