## Common networking state.  This is complicated.  Read the inline comments.

## Currently, networking is handled differently depending on
## whether or not your a physical machine or a virtual one
## This will probably be merged at some point, but for now
## this piece just determines which lookup you need to do
## to get the rest of your network configuration

{% if grains['virtual'] == 'physical' %}
  {% set srv = 'hosts' %}
{% else %}
  {% set srv = 'virtual' %}
{% endif %}

## This piece creates the following variables for all system-wide networks:
## 1. Full network as the variable {{ subnet }}_network (e.g. 1.2.3.0/24)
## 2. Network and subnet mask split as the variable {{ subnet }}_network_split (e.g. [1.2.3.4, 24])
## 3. Python list of network octets as the variable {{ subnet }}_netowkr_octets (e.g. [1,2,3,4]
## 4. Network mask as the variable {{ subnet }}_network_netmask (e.g. 24)

{% for subnet in pillar['networking']['subnets'] %}
  {% set subnet_network = pillar['networking']['subnets'][subnet] %}
  {% set subnet_network_split = subnet_network.split('/') %}
  {% set subnet_network_octets = subnet_network_split[0].split('.') %}
  {% set subnet_network_netmask = subnet_network_split[1] %}
[% endfor %}


## Get current management IP address.  This will be used to calculate the
## assigned addresses for all of the other networks.
{% set management_address_octets = grains['ipv4'][0].split('.') %}

## First case is the most common - no bridge.
{% if pillar[srv][grains['type']]['networks']['bridge'] == False %}
## Loop through all defined interfaces in the pillar for this particular device
{% for interface in pillar[srv][grains['type']]['networks']['interfaces'] %}
## Set short variable for easy reference
{% set current_network = pillar[srv][grains['type']]['networks']['interfaces'][interface]['network'] %}

## Actual state data starts here
  {{ interface }}:
    network.managed:
      - enabled: true
      - type: eth
## If working on the management interface, it should be set to DHCP
{% if current_network == 'management' %}
      - proto: dhcp
## Otherwise, calculate the IP address based on what management currently is.
{% else %}
      - proto: static
      - ipaddr: {{ subnet_network_octets[0] }}.{{ subnet_network_octets[1] }}.{{ management_address_octets[2] }}.{{ management_address_octets[3] }}/{{ subnet_network_netmask }}
{% endif %}
{% endif %}

networking_mine_update:
  module.run:
    - name: mine.update
  event.send:
    - name: {{ grains['type'] }}/mine/address/update
    - data: "{{ grains['type'] }} mine has been updated."
