# frozen_string_literal: true

source "https://rubygems.org"

gemspec

# CI runs the suite against several Rails versions: RAILS_VERSION=7.1 bundle install
rails_version = ENV["RAILS_VERSION"]
gem "rails", rails_version ? "~> #{rails_version}.0" : ">= 7.1"
gem "sqlite3", rails_version == "7.1" ? "~> 1.4" : ">= 2.1"
gem "minitest"
gem "rake"
