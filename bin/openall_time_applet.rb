#!/usr/bin/env ruby-1.9.2-head-stable

Dir.chdir(File.dirname(__FILE__))
require "../lib/openall_time_applet.rb"

GetText.bindtextdomain("default", "../locales", ENV["LANGUAGE"])

oata = Openall_time_applet.new(:debug => true)

Gtk.main