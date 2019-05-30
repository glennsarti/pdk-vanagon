source ENV['GEM_SOURCE'] || "https://rubygems.org"

def location_for(place)
  if place =~ /^(git[:@][^#]*)#(.*)/
    [{ :git => $1, :branch => $2, :require => false }]
  elsif place =~ /^file:\/\/(.*)/
    ['>= 0', { :path => File.expand_path($1), :require => false }]
  else
    [place, { :require => false }]
  end
end

gem 'vanagon', *location_for(ENV['VANAGON_LOCATION'] || '~> 0.15.19')
gem 'packaging', *location_for(ENV['PACKAGING_LOCATION'] || '~> 0.99.4')
gem 'rake', '~> 12.0'

#gem 'rubocop', "~> 0.34.2"


gem 'fuubar'

if RUBY_VERSION == "1.8.7"
  gem 'debugger'
elsif RUBY_VERSION =~ /^2\.[01]/
  gem "byebug", "~> 9.0.0"
  gem "pry-byebug"
elsif RUBY_VERSION =~ /^2\.[23456789]/
  gem "pry-byebug"
else
  gem "pry-debugger"
#  gem 'ruby-debug'
end

gem "pry-stack_explorer"
