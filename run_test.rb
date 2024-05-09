#!/usr/bin/env ruby

require "shellwords"

# Parse arguments
test_file, line_number, line_content = ARGV

def run_specific_test(test_file, line_number, line_content)
  cmd = "bundle exec rspec '#{test_file}:#{line_number}'"
  puts cmd
  system(cmd)
end

def run_all_tests_in_file(test_file)
  # Run all tests in the file
  system("bundle exec rspec '#{test_file}'")
end

if line_number && line_content
  run_specific_test(test_file, line_number, line_content)
else
  run_all_tests_in_file(test_file)
end
