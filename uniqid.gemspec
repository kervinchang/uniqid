require_relative 'lib/uniqid/version'

Gem::Specification.new do |spec|
  spec.name          = 'uniqid'
  spec.version       = Uniqid::VERSION
  spec.authors       = ['ChanKerwin']
  spec.email         = ['zhangcy.cn@outlook.com']

  spec.summary       = 'Unique ID Generator.'
  spec.description   = "A distributed unique ID generator inspired by Twitter's Snowflake."
  spec.homepage      = 'https://github.com/ChanKerwin/uniqid'
  spec.license       = 'MIT'

  spec.files         = Dir.chdir(File.expand_path(__dir__)) do
    `git ls-files -z`.split("\x0").reject { |f| f.match(%r{^(test|spec|features)/}) }
  end
  spec.bindir        = 'exe'
  spec.executables   = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  spec.require_paths = ['lib']

  spec.add_dependency 'rails'
  spec.add_development_dependency 'bundler'
  spec.add_development_dependency 'rake'
  spec.add_development_dependency 'rspec'
end
