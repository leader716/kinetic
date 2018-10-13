master_setup:
  salt.state:
    - tgt: 'salt'
    - highstate: true

pxe_setup:
  salt.state:
    - tgt: 'pxe'
    - highstate: true
    - require:
      - master_setup

wait_for_cache_hostname_assignment:
  salt.wait_for_event:
    - name: salt/job/*/ret/pxe
    - event_id: fun
    - id_list:
      - mine.send
    - timeout: 300

{% set cache_id = salt.saltutil.runner('mine.get',
    tgt='*',
    fun='file.read')%}

rotate_cache:
  salt.state:
    - tgt: 'salt'
    - sls:
      - formulas/salt/rotate_cache    
    - require:
      - pxe_setup

wait_for_cache_provisioning:
  salt.wait_for_event:
    - name: salt/auth
    - id_list:
      - {{ cache_id['pxe'] }}
    - timeout: 600

cache_setup:
  salt.state:
    - tgt: 'cache*'
    - highstate: true
    - require:
      - provision_cache
