# frozen_string_literal: true

require_relative 'lib/chronicle/version'

Gem::Specification.new do |spec|
  spec.name          = 'chronicle'
  spec.version       = Chronicle::VERSION
  spec.authors       = ['Chronicle Core Team']
  spec.email         = ['dev@github.com/Thrashattack/chronicle']

  spec.summary       = 'Active Record Datomic extension with convention over configuration'
  spec.description   = 'Chronicle integrates Datomic into Ruby on Rails Active Record, providing seamless CRuby/JRuby transport auto-detection, immutable time-travel queries, and cross-database ACID transaction coordination.'
  spec.homepage      = 'https://github.com/Thrashattack/chronicle'
  spec.license       = 'MIT'
  spec.required_ruby_version = '>= 3.4.5'

  spec.metadata['homepage_uri'] = spec.homepage
  spec.metadata['source_code_uri'] = spec.homepage
  spec.metadata['changelog_uri'] = 'https://github.com/Thrashattack/chronicle/blob/main/CHANGELOG.md'
  spec.metadata['allowed_push_host'] = 'https://rubygems.org'

  release_files = Dir.glob('lib/**/*').select { |path| File.file?(path) }
  spec.files = release_files + %w[README.md CHANGELOG.md LICENSE.txt]
  spec.require_paths = ['lib']

  spec.add_dependency 'activerecord', '>= 7.0.0'
  spec.add_dependency 'activesupport', '>= 7.0.0'
  spec.add_dependency 'base64', '>= 0.2.0'
  spec.add_dependency 'drb', '>= 2.2'
  spec.add_dependency 'edn', '~> 1.1'
  spec.add_dependency 'faraday', '>= 2.0.0'
  spec.add_dependency 'logger', '>= 1.6'
  spec.add_dependency 'mutex_m', '>= 0.2.0'
  spec.add_dependency 'ostruct', '>= 0.6'

  spec.add_development_dependency 'pg', '~> 1.5'
  spec.add_development_dependency 'rails', '~> 8.1'
  spec.add_development_dependency 'rake', '~> 13.0'
  spec.add_development_dependency 'rspec', '~> 3.12'
  spec.add_development_dependency 'simplecov', '~> 0.22'
  spec.add_development_dependency 'sqlite3', '~> 2.1'
  spec.metadata['rubygems_mfa_required'] = 'true'
end
