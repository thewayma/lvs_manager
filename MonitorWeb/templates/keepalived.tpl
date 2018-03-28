global_defs {  
   router_id {{ router_id }}
}

{% set rvid = 0 %}

include ./local_address.conf

{% for vipinstance in vip_instance_list %}
{% if vipinstance.status != 'offline' %}

vrrp_instance {{ vipinstance.vip_instance }}  {
    state BACKUP    #主备都是backup, 启动时高priority将选为主
    interface {{ vipinstance.vip_nic}}
    virtual_router_id {% set rvid = rvid%256 %}{{ rvid }}{% set rvid = rvid + 1 %}  #VRID可用值0-255，即lvs设备上最多可以定义256个vrrp实例

    #多个vrrp实例时, 主备直接轮流切换, 最大化资源利用率
    {% set master = master%2 %}
    {% if master == 0 %}
        priority 100    #主机上设置成100
    {% else %}
        priority 90     #备机上设置成90
    {% endif %}
    {% set master = master + 1 %}

    advert_int 1
    nopreempt FALSE    #设置成切换不抢占
    authentication {
        auth_type PASS
        auth_pass wocao
    }
    virtual_ipaddress {
        {% for vip in vipinstance.vip_group %}
            {{ vip.vip }} {{ vip.port }} #{{ vipinstance.descript }}
        {% endfor %}
    }
}


virtual_server_group {{ vipinstance.vip_instance }} {
    {% for vip in vipinstance.vip_group %}
    {{ vip.vip }} {{ vip.port }} #{{ vipinstance.descript }}
    {% endfor %}
}

virtual_server group  {{ vipinstance.vip_instance }} {
  delay_loop {{ vipinstance.delay_loop }}
  lb_algo {{ vipinstance.lb_algo }} 
  lb_kind {{ vipinstance.lb_kind }}
  protocol {{ vipinstance.protocol }}
  persistence_timeout {{ vipinstance.persistence_timeout }}
  {% if vipinstance.sync_proxy %}syn_proxy{% endif %}
  laddr_group_name laddr_g1
  {% if vipinstance.alpha %}alpha{% endif %}
  {% if vipinstance.omega %}omega{% endif %}
  quorum {{ vipinstance.quorum }}
  hysteresis {{ vipinstance.hysteresis }}
  quorum_up "{% for vip in vipinstance.vip_group %}ip addr add {{ vip.vip }}/32 dev lo ;{% endfor %}"
  {% if vipinstance.omega %}
  quorum_down "{% for vip in vipinstance.vip_group %}ip addr del {{ vip.vip }}/32 dev lo ;{% endfor %}"
  {% endif %}
 
  {% for rs in vipinstance.rs %}
	  {% for rs_port in rs.port %}
	  real_server {{ rs.server_ip }} {{ rs_port }} {
	    weight {{ rs.weight }}                                         
	    inhibit_on_failure
	    {% if rs.monitor.type == 'HTTP_GET' %}
	    HTTP_GET {
	    url {
	        path {{ rs.monitor.path }}
	        digest {{ rs.monitor.digest }}
	      }
	        connect_timeout {{ rs.monitor.connect_timeout }}
	        nb_get_retry {{ rs.monitor.nb_get_retry }}
	        delay_before_retry {{ rs.monitor.delay_before_retry }}
	        connect_port {{ rs_port }}
	    }
	    {% elif rs.monitor.type == 'TCP_CHECK' %}
	    TCP_CHECK {
        	connect_timeout {{ rs.monitor.connect_timeout }}
        	connect_port {{ rs_port }}
    	}
    	{% elif rs.monitor.type == 'MISC_CHECK' %}
    	MISC_CHECK {
           misc_path "{{ rs.monitor.misc_path }}"
           misc_timeout {{ rs.monitor.misc_timeout }}
       	}
	    {% endif %}  
    }                       
	  {% endfor %}
  {% endfor %}
}
{% endif %}

{% endfor %}
