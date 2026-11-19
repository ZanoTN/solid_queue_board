# frozen_string_literal: true

require "bundler/gem_tasks"
require "rake/testtask"

Rake::TestTask.new(:test) do |t|
  t.libs << "test"
  t.pattern = "test/**/*_test.rb"
end

desc "Start the demo app on http://localhost:3000/jobs (PORT=3000 to change)"
task :demo do
  Dir.chdir("demo") do
    Bundler.with_unbundled_env do
      system("bundle install --quiet") || abort("bundle install failed")
      exec("bundle", "exec", "rackup", "-p", ENV.fetch("PORT", "3000"), "-o", "0.0.0.0")
    end
  end
end

task default: :test
