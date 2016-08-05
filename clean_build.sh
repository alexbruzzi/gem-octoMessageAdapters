rm *.gem
gem build octomessageadapters.gemspec && gem uninstall octomessageadapters --force && gem install octomessageadapters-0.0.1.gem