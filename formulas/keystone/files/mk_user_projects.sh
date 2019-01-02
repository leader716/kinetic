#!/bin/bash
## This script will enumerate the directory and identify all users that are part of the domain group.
## It will then iterate through that list one-by-one and test if a user project for that user exists.  If a
## project does exist, it will do nothing.  If a project does not exist, it will create it.  This script
## should be periodically run as part of a highstate as well as when new users are added to the system.
#!/bin/bash
export OS_USERNAME=admin
export OS_PASSWORD={{ admin_password }}
export OS_PROJECT_NAME=admin
export OS_USER_DOMAIN_NAME=Default
export OS_PROJECT_DOMAIN_NAME=Default
export OS_AUTH_URL={{ internal_endpoint }}
export OS_IDENTITY_API_VERSION=3

project_test=$(openstack project list | grep service)

if [[ $project_test != '' ]]; then
  echo 'Existing service project detected...skipping creation...'
  echo $project_test
else
  openstack project create --domain default --description "Service Project" service
fi

user_role_test=$(openstack role list | grep user)

if [[ $user_role_test != '' ]]; then
  echo 'Existing user role detected...skipping creation...'
  echo $user_role_test
else
  openstack role create user
fi

service_user_test=$(openstack user list | grep keystone)

if [[ $service_user_test != '' ]]; then
  echo 'Existing keystone service user detected...skipping creation...'
  echo $service_user_test
else
openstack user create --domain default --password {{ keystone_service_password }} keystone
openstack role add --project service --user keystone admin
fi

ldap_domain_test=$(openstack domain list | grep "LDAP Domain")

if [[ $ldap_domain_test != '' ]]; then
  echo 'Existing ldap domain detected...skipping creation...'
  echo $ldap_domain_test
else
  openstack domain create --description "LDAP Domain" {{ keystone_domain }}
fi

# Get current project list in the specified keystone domain and save to /tmp/{{ keystone_domain }}_projects
openstack project list --domain {{ keystone_domain }} > /tmp/{{ keystone_domain }}_projects
openstack user list --domain {{ keystone_domain }} | grep -P '[[:alnum:]]{64}' | awk '{ print $4 }' | while read uid
do
  project_test=$(grep $uid /tmp/{{ keystone_domain }}_projects)
  if [[ $project_test != '' ]]; then
    echo -n 'Existing '
    echo -n $uid
    echo ' project detected...skipping creation...'
    echo $project_test
  else
    openstack project create $uid --domain {{ keystone_domain }}
    openstack role add --user $uid --user-domain {{ keystone_domain }} --project $uid --project-domain {{ keystone_domain }} user
  fi
done

# Cleanup
rm /tmp/{{ keystone_domain }}_projects
