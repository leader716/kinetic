master_setup:
  salt.state:
    - tgt: 'salt'
    - highstate: true

{% for type in pillar['virtual'] %}
  {% set count = pillar['virtual'][type]['config']['count'] %}
  {% for host in range(count) %}
func_create_{{ type}}_{{ host }}:
  salt.function:
    - name: cmd.run
    - tgt: salt
    - arg:
      - echo {{ type }} {{ count }}
  {% endfor %}
{% endfor %}