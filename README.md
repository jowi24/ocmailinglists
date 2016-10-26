# Owncloud/Nextcloud mailinglist generator

Generate an exim forward file to create mailing lists for each owncloud/nextcloud group.

This perl script creates an exim forwardfile `$HOME/.forward`, based on the users and groups in an owncloud/nextcloud installation. It uses the [Owncloud User Provisioning API](https://doc.owncloud.org/server/8.0/admin_manual/configuration_user/user_provisioning_api.html) to access information about users and groups. An optional system.filter (see example file in repository) can be used with exim to modify mails before forwarding them.

For each group *groupname*, it creates a mailinglist, i.e., mails sent to *groupname@domain.com* are forwarded to each member of the group *groupname*. You can also define, that a mailinglist is private, which means, that only members of the group are allowed to send mail to *groupname@domain.com*. A catch-all definition is possible, that sends all mail to domain.com which does not match any group to a specific recipient.

Script usage is as follows:

`generate-mailinglists.pl --user|-u <username> --pass|-p <password> --host|-h <hostname> [--catch-all <email>] [--private <private-list-id>] [--verbose|-v] [--help|-?]`

* `username` is an owncloud admin user (required)
* `password` is the corresponding password (required)
* `hostname` is the owncloud hostname (required)
* `email` specifies an optional catch-all email address (optional)
* `private-list-id` defines an specific group as private (optional, can be specified multiple times)
    
Example:

`generate-mailinglists.pl -u admin -p secret -h owncloud.domain.com --private intern --private workgroup`

To periodically update the forward file just put the script in your cronfile.
