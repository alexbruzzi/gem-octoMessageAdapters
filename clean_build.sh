rm *.gem
gem build octomessageadapters.gemspec && gem uninstall octomessageadapters --force
find . -name '*.gem' | xargs gem install