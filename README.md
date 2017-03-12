SimpleSAMLphp
=============

This is NOT the official repository of the SimpleSAMLphp software.

* [Original Source Repo](https://github.com/simplesamlphp)
* [SimpleSAMLphp homepage](https://simplesamlphp.org)
* [SimpleSAMLphp Downloads](https://simplesamlphp.org/download)

This is a code fork for the simplesamlphp in it's configured, ready to deploy to Cloud Foundry format.

This is used for to test SAML authentication with Ops Manager, Bosh Director, ERT, and SSO

# Preconfigured Users
IDP Admin User login: admin / password [ mapped to pcfadmins group [config/authsources.php](config/authsources.php) <br>
IDP User login: user / password [ mapped to pcfusers group see [config/authsources.php](config/authsources.php)
simplesamlphp Admin login: admin / pizza9pixel


# Deployment 

1. Edit the [config.yml](config.yml) with the uaa endpoints that match your environment

  * opsman_uaa: https://opsman.domain:443
  * bosh_uaa: https://BOSH_DIRECTOR_IP:8443
  * ert_uaa: [ http://login.system.domain || http://sso.login.system.domain ]
    * Important NOTE:  ERT tile hard codes the [entityid](https://github.com/pivotal-cf/p-runtime/blob/rel/1.10/metadata_parts/jobs/uaa.yml#L336) with `http` instead of `https` and this causes some issues with simplesamlphp.  This commit [7c467ce5e065651f4d57423dcd08f64fa883a721](7c467ce5e065651f4d57423dcd08f64fa883a721) works around the  problem but the SP metadata in [config.yml](config.yml) will need to have http to match the IDP metatdata with the UAA. 
  * app_name: the name of the deployed cloud foundry app

```
opsman_uaa: "https://opsmgr.domain:443"
bosh_uaa: "https://10.1.1.11:8443"
ert_uaa: "http://login.system.domain"
app_name: "mysaml"
```

2. make sure you are logged into the api endpoine and start the deployment 

```
$ ./deploy_new_saml_server.rb config.yml

################################################
# Using the following federation configuration #
################################################

<?php

$metadata['https://opsmgr.domain:443/uaa'] = array(
    'AssertionConsumerService' => 'https://opsmgr.domain:443/uaa/saml/SSO/alias/opsmgr.domain',
    'SingleLogoutService' => 'https://opsmgr.domain:443/uaa/saml/SingleLogout/alias/opsmgr.domain',
    'NameIDFormat' => 'urn:oasis:names:tc:SAML:1.1:nameid-format:emailAddress',
    'simplesaml.nameidattribute' => 'emailAddress',
);


$metadata['https://10.1.1.11:8443'] = array(
    'AssertionConsumerService' => 'https://10.1.1.11:8443/saml/SSO/alias/10.1.1.11',
    'SingleLogoutService' => 'https://10.1.1.11:8443/saml/SingleLogout/alias/10.1.1.11',
    'NameIDFormat' => 'urn:oasis:names:tc:SAML:1.1:nameid-format:emailAddress',
    'simplesaml.nameidattribute' => 'emailAddress',
);


$metadata['http://login.system.domain'] = array(
    'AssertionConsumerService' => 'https://login.system.domain/saml/SSO/alias/login.system.domain',
    'SingleLogoutService' => 'https://login.system.domain/saml/SingleLogout/alias/login.system.domain',
    'NameIDFormat' => 'urn:oasis:names:tc:SAML:1.1:nameid-format:emailAddress',
    'simplesaml.nameidattribute' => 'emailAddress',
);

################################################

ready to run cf push mysaml? [y/n]:
```

# Mapping external groups with ERT UAA

1. Target the ERT uaa 

```
uaac target https://login.system.domain --skip-ssl-validation
```

2. Use uaac to get the admin client token

```
uaac token client get
```

3. Map the external groups to what ever scopes you like.  Here is an example of mapping the admin@test.org user to cloud_controler.admin scope 

```
uaac group map --name cloud_controller.admin pcfadmins --origin simplesamlphp
```

# Setting LDAP as a auth provider 

