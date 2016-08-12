require File.expand_path('../lib/messageadapter/version', __FILE__)

Gem::Specification.new do |s|
  s.name        = 'octomessageadapters'
  s.version     = Adapter::MessageAdapter::VERSION

  s.summary     = 'Octo Message Adapter(s) Module'
  s.description = <<DESC
  Contains third party adapters
DESC

  s.authors     = ['Ravin Gupta']
  s.email       = 'ravin.gupta@octo.ai'
  s.files       = Dir['lib/**/*.rb', 'spec/**/*.rb', '[A-Z]*']

  s.homepage    =
      'https://bitbucket.org/auroraborealisinc/gems'
  s.license       = 'MIT'

  s.has_rdoc    = true
  s.extra_rdoc_files = 'README.md'

  s.required_ruby_version = '>= 2.0'

  s.add_runtime_dependency 'octocore', '~> 0.0.5', '>= 0.0.5'
  s.add_runtime_dependency 'staccato', '~> 0.4.7', '>= 0.4.7'
  s.add_runtime_dependency 'resque', '~> 1.26.0', '>= 1.26.0'
  s.add_runtime_dependency 'resque-scheduler', '~> 4.1.0', '>= 4.1.0'

end