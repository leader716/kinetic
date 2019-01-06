include:
  - formulas/cephmon/install
  - formulas/common/base
  - formulas/common/networking

/etc/ceph/ceph.conf:
  file.managed:
    - source: salt://formulas/cephmon/files/ceph.conf
    - template: jinja
    - makedirs: True
    - defaults:
        fsid: {{ pillar['ceph']['fsid'] }}
        mon_members: |
          {% for host, address in salt['mine.get']('role:cephmon', 'network.ip_addrs', tgt_type='grain') | dictsort() %}
          [mon.{{ host }}]
          host = {{ host }}
          mon addr = {{ address[0] }}
          {% endfor %}
        swift_members: |
          {% for host, address in salt['mine.get']('role:swift', 'network.ip_addrs', tgt_type='grain') | dictsort() %}
          [client.swift.{{ host }}]
          host = {{ host }}
          rgw_keystone_url = {{ pillar ['openstack_services']['keystone']['configuration']['internal_endpoint']['protocol'] }}{{ pillar['endpoints']['internal'] }}{{ pillar ['openstack_services']['keystone']['configuration']['internal_endpoint']['port'] }}{{ pillar ['openstack_services']['keystone']['configuration']['internal_endpoint']['path'] }}
          rgw keystone api version = 3
          rgw keystone admin user = keystone
          rgw keystone admin password = {{ pillar ['keystone']['keystone_service_password'] }}
          rgw keystone admin project = service
          rgw keystone admin domain = default
          rgw keystone accepted roles = admin,user
          rgw keystone token cache size = 10
          rgw keystone revocation interval = 300
          rgw keystone implicit tenants = true
          rgw swift account in url = true
          {% endfor %}
        sfe_network: {{ pillar['subnets']['sfe'] }}
        sbe_network: {{ pillar['subnets']['sbe'] }}

/tmp/ceph.mon.keyring:
  file.managed:
    - contents_pillar: ceph:ceph-mon-keyring
    - mode: 600
    - user: ceph
    - group: ceph

/etc/ceph/ceph.client.admin.keyring:
  file.managed:
    - contents_pillar: ceph:ceph-client-admin-keyring

/etc/ceph/ceph.client.images.keyring:
  file.managed:
    - contents_pillar: ceph:ceph-client-images-keyring

/etc/ceph/ceph.client.volumes.keyring:
  file.managed:
    - contents_pillar: ceph:ceph-client-volumes-keyring

/etc/ceph/ceph.client.compute.keyring:
  file.managed:
    - contents_pillar: ceph:ceph-client-compute-keyring

{% for host, address in salt['mine.get']('role:swift', 'network.ip_addrs', tgt_type='grain') | dictsort() %}
ceph auth get cient.swift.{{ host }} > /etc/ceph/ceph.client.swift.keyring:
  cmd.run
{% endfor %}

/var/lib/ceph/bootstrap-osd/ceph.keyring:
  file.managed:
    - contents_pillar: ceph:ceph-keyring

/var/lib/ceph/mon/ceph-{{ grains['id'] }}:
  file.directory:
    - user: ceph
    - group: ceph
    - recurse:
      - user
      - group

monmaptool --create --generate --clobber -c /etc/ceph/ceph.conf /tmp/monmap:
  cmd.run:
    - creates:
      - /tmp/monmap

ceph-mon --cluster ceph --mkfs -i {{ grains['id'] }} --monmap /tmp/monmap --keyring /tmp/ceph.mon.keyring && touch /var/lib/ceph/mon/ceph-{{ grains['id'] }}/done:
  cmd.run:
    - runas: ceph
    - requires:
      - /var/lib/ceph/mon/ceph-{{ grains['id'] }}
    - creates:
      - /var/lib/ceph/mon/ceph-{{ grains['id'] }}/done

ceph-mon@{{ grains['id'] }}:
  service.running:
    - watch:
      - file: /etc/ceph/ceph.conf

/var/lib/ceph/mgr/ceph-{{ grains['id'] }}:
  file.directory:
    - user: ceph
    - group: ceph

ceph auth get-or-create mgr.{{ grains['id'] }} mon 'allow profile mgr' osd 'allow *' mds 'allow *' > /var/lib/ceph/mgr/ceph-{{ grains['id'] }}/keyring:
  cmd.run:
    - creates:
      - /var/lib/ceph/mgr/ceph-{{ grains['id'] }}/keyring

ceph-mgr@{{ grains['id'] }}:
  service.running:
    - enable: true
    - watch:
      - cmd: ceph auth get-or-create mgr.{{ grains['id'] }} mon 'allow profile mgr' osd 'allow *' mds 'allow *' > /var/lib/ceph/mgr/ceph-{{ grains['id'] }}/keyring

fs.file-max:
  sysctl.present:
    - value: 500000

/etc/security/limits.conf:
  file.managed:
    - source: salt://formulas/cephmon/files/limits.conf

ceph auth import -i /etc/ceph/ceph.client.images.keyring:
  cmd.run:
    - onchanges:
      - /etc/ceph/ceph.client.images.keyring
    - require:
      - service: ceph-mon@{{ grains['id'] }}

ceph auth import -i /etc/ceph/ceph.client.volumes.keyring:
  cmd.run:
    - onchanges:
      - /etc/ceph/ceph.client.volumes.keyring
    - require:
      - service: ceph-mon@{{ grains['id'] }}

ceph auth import -i /etc/ceph/ceph.client.compute.keyring:
  cmd.run:
    - onchanges:
      - /etc/ceph/ceph.client.compute.keyring
    - require:
      - service: ceph-mon@{{ grains['id'] }}
