include:
  - formulas/magnum/install
  - formulas/common/base
  - formulas/common/networking

{% if grains['spawning'] == 0 %}

make_magnum_service:
  cmd.script:
    - source: salt://formulas/magnum/files/mkservice.sh
    - template: jinja
    - defaults:
        admin_password: {{ pillar['openstack']['admin_password'] }}
        keystone_internal_endpoint: {{ pillar ['openstack_services']['keystone']['configuration']['internal_endpoint']['protocol'] }}{{ pillar['endpoints']['internal'] }}{{ pillar ['openstack_services']['keystone']['configuration']['internal_endpoint']['port'] }}{{ pillar ['openstack_services']['keystone']['configuration']['internal_endpoint']['path'] }}
        magnum_internal_endpoint: {{ pillar ['openstack_services']['magnum']['configuration']['internal_endpoint']['protocol'] }}{{ pillar['endpoints']['internal'] }}{{ pillar ['openstack_services']['magnum']['configuration']['internal_endpoint']['port'] }}{{ pillar ['openstack_services']['magnum']['configuration']['internal_endpoint']['path'] }}
        magnum_public_endpoint: {{ pillar ['openstack_services']['magnum']['configuration']['public_endpoint']['protocol'] }}{{ pillar['endpoints']['public'] }}{{ pillar ['openstack_services']['magnum']['configuration']['public_endpoint']['port'] }}{{ pillar ['openstack_services']['magnum']['configuration']['public_endpoint']['path'] }}
        magnum_admin_endpoint: {{ pillar ['openstack_services']['magnum']['configuration']['admin_endpoint']['protocol'] }}{{ pillar['endpoints']['admin'] }}{{ pillar ['openstack_services']['magnum']['configuration']['admin_endpoint']['port'] }}{{ pillar ['openstack_services']['magnum']['configuration']['admin_endpoint']['path'] }}
        magnum_service_password: {{ pillar ['magnum']['magnum_service_password'] }}

magnum-db-manage upgrade:
  cmd.run:
    - runas: magnum
    - require:
      - file: /etc/magnum/magnum.conf

spawnzero_complete:
  event.send:
    - name: {{ grains['type'] }}/spawnzero/complete
    - data: "{{ grains['type'] }} spawnzero is complete."

{% endif %}

/etc/magnum/magnum.conf:
  file.managed:
    - source: salt://formulas/magnum/files/magnum.conf
    - template: jinja
    - defaults:
{% for server, address in salt['mine.get']('type:rabbitmq', 'network.ip_addrs', tgt_type='grain') | dictsort() %}
        transport_url: rabbit://openstack:{{ pillar['rabbitmq']['rabbitmq_password'] }}@{{ address[0] }}
{% endfor %}
{% for server, address in salt['mine.get']('type:mysql', 'network.ip_addrs', tgt_type='grain') | dictsort() %}
        connection: mysql+pymysql://magnum:{{ pillar['magnum']['magnum_mysql_password'] }}@{{ address[0] }}/magnum
{% endfor %}
        www_authenticate_uri: {{ pillar ['openstack_services']['keystone']['configuration']['public_endpoint']['protocol'] }}{{ pillar['endpoints']['public'] }}{{ pillar ['openstack_services']['keystone']['configuration']['public_endpoint']['port'] }}{{ pillar ['openstack_services']['keystone']['configuration']['public_endpoint']['path'] }}
        auth_url: {{ pillar ['openstack_services']['keystone']['configuration']['internal_endpoint']['protocol'] }}{{ pillar['endpoints']['internal'] }}{{ pillar ['openstack_services']['keystone']['configuration']['internal_endpoint']['port'] }}
{% for server, address in salt['mine.get']('type:memcached', 'network.ip_addrs', tgt_type='grain') | dictsort() %}
        memcached_servers: {{ address[0] }}:11211
{% endfor %}
        password: {{ pillar['magnum']['magnum_service_password'] }}
        host: {{ salt['network.ipaddrs'](cidr=pillar['networking']['subnets']['management'])[0] }}

magnum_conductor_service:
  service.running:
{% if grains['os_family'] == 'Debian' %}
    - name: magnum-conductor
{% elif grains['os_family'] == 'RedHat' %}
    - name: openstack-magnum-conductor
{% endif %}
    - enable: True
    - watch:
      - file: /etc/magnum/magnum.conf

magnum_api_service:
  service.running:
{% if grains['os_family'] == 'Debian' %}
    - name: magnum-api
{% elif grains['os_family'] == 'RedHat' %}
    - name: openstack-magnum-api
{% endif %}
    - enable: true
    - watch:
      - file: /etc/magnum/magnum.conf