Gem::Specification.new do |s|
    s.name          = "dsm-portfolio-plugin"
    s.version       = "0.0.25"
    s.licenses      = ['MIT']
    s.summary       = "Jekyll plugin necessary for dsm-portfolio-theme to function."
    s.description   = "Generates site project data and declares custom tags."
    s.authors       = ["Josh Hills"]
    s.email         = 'josh@jargonify.com'
    s.files = [
      "lib/dsm-portfolio-plugin.rb"
    ]
    s.require_paths = ['lib']
    s.homepage      = 'https://github.com/joshhills/dsm-portfolio-plugin'
    s.metadata      = { "source_code_uri" => "https://github.com/joshhills/dsm-portfolio-plugin" }
  
    s.add_dependency "jekyll", "~> 3.8"
  end