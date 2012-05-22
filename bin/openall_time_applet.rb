#!/usr/bin/env ruby1.9

Dir.chdir(File.dirname(__FILE__))
require "../lib/openall_time_applet.rb"

GetText.bindtextdomain("default", "../locales", ENV["LANGUAGE"])

oata = Openall_time_applet.new

Gtk.main