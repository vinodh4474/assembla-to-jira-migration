# frozen_string_literal: true

source 'https://rubygems.org'

ruby '2.7.1p83'

git_source(:github) do |repo_name|
  repo_name = "#{repo_name}/#{repo_name}" unless repo_name.include?('/')
  "https://github.com/#{repo_name}.git"
end

gem 'dotenv'
gem 'rest-client'
gem 'i18n'

gem 'htmlbeautifier'

gem 'rubocop', require: false
