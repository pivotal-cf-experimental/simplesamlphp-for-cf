#!/usr/bin/env ruby

require 'uri'
require "yaml"

def self.run(cmd)
  system(cmd) or raise "Failed to run #{cmd}"
end

def prompt(string)
  print string
  STDOUT.flush
  $stdin.gets.chomp
end

configFile = ARGV.first

opsman_url = ""
bosh_url = ""
ert_url = ""
myconfig = ""
name = "" # app name

if ARGV.length > 0 
  myconfig = YAML.load_file(ARGV.first)
  opsman_url = myconfig['opsman_uaa']
  bosh_url = myconfig['bosh_uaa']
  ert_url = myconfig['ert_uaa']
  name = myconfig['app_name']
else
  puts 'We need to know the locations of your Ops Manager and BOSH director UAAs...'
  opsman_url = prompt "What is the scheme, host and port of your Ops Manager's UAA? (Example 'https://opsmgr-xx.haas-59.pez.pivotal.io:443') "
  opsman_url = 'http://localhost:8080' if opsman_url.empty?
  bosh_url = prompt "What is the scheme, host and port of your BOSH director's UAA? (Example 'https://DIRECTOR_IP:8443'). Leave this empty if the director has not been deployed yet. "
  ert_url = prompt "What is the scheme, hostname of your ERT SSO identity zone? (Example 'https://login.run-17.haas-59.pez.pivotal.io/saml/metadata:443'). optional leave blank to ignore. "
  name = prompt 'App name on PCF: '
end

opsman_entity_id = opsman_url + '/uaa'
bosh_entity_id = bosh_url
ert_entity_id = ert_url

opsman_entity_alias = URI(opsman_url).host
bosh_entity_alias = URI(bosh_url).host
ert_entity_alias = URI(ert_url).host

opsman_metadata = <<-PHP
$metadata['#{opsman_entity_id}'] = array(
    'AssertionConsumerService' => '#{opsman_url}/uaa/saml/SSO/alias/#{opsman_entity_alias}',
    'SingleLogoutService' => '#{opsman_url}/uaa/saml/SingleLogout/alias/#{opsman_entity_alias}',
    'NameIDFormat' => 'urn:oasis:names:tc:SAML:1.1:nameid-format:emailAddress',
    'simplesaml.nameidattribute' => 'emailAddress',
);
PHP

bosh_metadata = <<-PHP
$metadata['#{bosh_entity_id}'] = array(
    'AssertionConsumerService' => '#{bosh_url}/saml/SSO/alias/#{bosh_entity_alias}',
    'SingleLogoutService' => '#{bosh_url}/saml/SingleLogout/alias/#{bosh_entity_alias}',
    'NameIDFormat' => 'urn:oasis:names:tc:SAML:1.1:nameid-format:emailAddress',
    'simplesaml.nameidattribute' => 'emailAddress',
);
PHP

ert_metadata = <<-PHP
$metadata['#{ert_entity_id}'] = array(
    'AssertionConsumerService' => '#{ert_url}/saml/SSO/alias/#{ert_entity_alias}',
    'SingleLogoutService' => '#{ert_url}/saml/SingleLogout/alias/#{ert_entity_alias}',
    'NameIDFormat' => 'urn:oasis:names:tc:SAML:1.1:nameid-format:emailAddress',
    'simplesaml.nameidattribute' => 'emailAddress',
);
PHP

metadata_file = '<?php' + "\n\n" + opsman_metadata + "\n\n"
metadata_file += bosh_metadata unless bosh_url.empty?
metadata_file += "\n\n" + ert_metadata unless ert_url.empty?

File.write('metadata/saml20-sp-remote.php', metadata_file)

if name.length == 0
  puts 'Aborting.'
  run 'git checkout metadata/saml20-sp-remote.php'
  exit
end

puts
puts "\#\#\#\#\#\#\#\#\#\#\#\#\#\#\#\#\#\#\#\#\#\#\#\#\#\#\#\#\#\#\#\#\#\#\#\#\#\#\#\#\#\#\#\#\#\#\#\#"
puts "\# Using the following federation configuration \#"
puts "\#\#\#\#\#\#\#\#\#\#\#\#\#\#\#\#\#\#\#\#\#\#\#\#\#\#\#\#\#\#\#\#\#\#\#\#\#\#\#\#\#\#\#\#\#\#\#\#"
puts
puts File.read('metadata/saml20-sp-remote.php')
puts
puts "\#\#\#\#\#\#\#\#\#\#\#\#\#\#\#\#\#\#\#\#\#\#\#\#\#\#\#\#\#\#\#\#\#\#\#\#\#\#\#\#\#\#\#\#\#\#\#\#\n\n"

ask = prompt "ready to run cf push #{name}? [y/n]: " 
if ask.downcase != "y"
  puts "\nCanceling execution...\n"
  exit 
end

run "cf push #{name} -n #{name} -m 128M -b https://github.com/cf-identity/php-buildpack.git"
run 'git checkout metadata/saml20-sp-remote.php'
