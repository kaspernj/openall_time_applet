# Generated by jeweler
# DO NOT EDIT THIS FILE DIRECTLY
# Instead, edit Jeweler::Tasks in Rakefile, and run 'rake gemspec'
# -*- encoding: utf-8 -*-

Gem::Specification.new do |s|
  s.name = %q{openall_time_applet}
  s.version = "0.0.24"

  s.required_rubygems_version = Gem::Requirement.new(">= 0") if s.respond_to? :required_rubygems_version=
  s.authors = ["Kasper Johansen"]
  s.date = %q{2012-07-17}
  s.description = %q{Off-line time-tracking for OpenAll with syncing when online.}
  s.email = %q{k@spernj.org}
  s.executables = ["OpenAll Timelogging", "openall_time_applet.rb"]
  s.extra_rdoc_files = [
    "LICENSE.txt",
    "README.rdoc"
  ]
  s.files = [
    ".document",
    ".rspec",
    "Gemfile",
    "Gemfile.lock",
    "LICENSE.txt",
    "README.rdoc",
    "Rakefile",
    "VERSION",
    "bin/OpenAll Timelogging",
    "bin/openall_time_applet.rb",
    "classes/connection.rb",
    "classes/translations.rb",
    "classes/unix_socket.rb",
    "conf/db_schema.rb",
    "gfx/icon_time_black.png",
    "gfx/icon_time_green_casalogic.png",
    "gfx/icon_time_orig.png",
    "gfx/icon_time_white.png",
    "glade/win_main.glade",
    "glade/win_overview.glade",
    "glade/win_preferences.glade",
    "glade/win_worktime_overview.glade",
    "gui/trayicon.rb",
    "gui/win_main.rb",
    "gui/win_preferences.rb",
    "gui/win_worktime_overview.rb",
    "lib/openall_time_applet.rb",
    "locales/da_DK/LC_MESSAGES/default.mo",
    "locales/da_DK/LC_MESSAGES/default.po",
    "models/organisation.rb",
    "models/task.rb",
    "models/timelog.rb",
    "models/timelog_logged_time.rb",
    "models/worktime.rb",
    "openall_time_applet.gemspec",
    "spec/openall_time_applet_spec.rb",
    "spec/spec_helper.rb"
  ]
  s.homepage = %q{http://github.com/kaspernj/openall_time_applet}
  s.licenses = ["MIT"]
  s.require_paths = ["lib"]
  s.rubygems_version = %q{1.6.2}
  s.summary = %q{Time-tracking for OpenAll.}

  if s.respond_to? :specification_version then
    s.specification_version = 3

    if Gem::Version.new(Gem::VERSION) >= Gem::Version.new('1.2.0') then
      s.add_runtime_dependency(%q<knjrbfw>, [">= 0"])
      s.add_runtime_dependency(%q<gtk2>, [">= 0"])
      s.add_runtime_dependency(%q<sqlite3>, [">= 0"])
      s.add_runtime_dependency(%q<gettext>, [">= 0"])
      s.add_runtime_dependency(%q<json>, [">= 0"])
      s.add_runtime_dependency(%q<rmagick>, [">= 0"])
      s.add_runtime_dependency(%q<datet>, [">= 0"])
      s.add_runtime_dependency(%q<http2>, [">= 0"])
      s.add_development_dependency(%q<rspec>, ["~> 2.8.0"])
      s.add_development_dependency(%q<rdoc>, ["~> 3.12"])
      s.add_development_dependency(%q<bundler>, [">= 1.0.0"])
      s.add_development_dependency(%q<jeweler>, ["~> 1.8.3"])
    else
      s.add_dependency(%q<knjrbfw>, [">= 0"])
      s.add_dependency(%q<gtk2>, [">= 0"])
      s.add_dependency(%q<sqlite3>, [">= 0"])
      s.add_dependency(%q<gettext>, [">= 0"])
      s.add_dependency(%q<json>, [">= 0"])
      s.add_dependency(%q<rmagick>, [">= 0"])
      s.add_dependency(%q<datet>, [">= 0"])
      s.add_dependency(%q<http2>, [">= 0"])
      s.add_dependency(%q<rspec>, ["~> 2.8.0"])
      s.add_dependency(%q<rdoc>, ["~> 3.12"])
      s.add_dependency(%q<bundler>, [">= 1.0.0"])
      s.add_dependency(%q<jeweler>, ["~> 1.8.3"])
    end
  else
    s.add_dependency(%q<knjrbfw>, [">= 0"])
    s.add_dependency(%q<gtk2>, [">= 0"])
    s.add_dependency(%q<sqlite3>, [">= 0"])
    s.add_dependency(%q<gettext>, [">= 0"])
    s.add_dependency(%q<json>, [">= 0"])
    s.add_dependency(%q<rmagick>, [">= 0"])
    s.add_dependency(%q<datet>, [">= 0"])
    s.add_dependency(%q<http2>, [">= 0"])
    s.add_dependency(%q<rspec>, ["~> 2.8.0"])
    s.add_dependency(%q<rdoc>, ["~> 3.12"])
    s.add_dependency(%q<bundler>, [">= 1.0.0"])
    s.add_dependency(%q<jeweler>, ["~> 1.8.3"])
  end
end

