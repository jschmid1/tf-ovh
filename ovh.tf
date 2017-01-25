provider "openstack" {}

data "template_file" "master-bootstrap" {
  template = "${file("master-bootstrap.tpl")}"
  vars {
    master_ip = "${cidrhost(var.master_subnet, var.master_ip)}"
    prefix = "${var.vm_name_prefix}"
  }
}

data "template_file" "minion-bootstrap" {
  count = "${var.minion_count}"
  template = "${file("minion-bootstrap.tpl")}"
  vars {
    master_ip = "${cidrhost(var.master_subnet, var.master_ip)}"
    node_name = "${var.vm_name_prefix}-salt-minion-${count.index}"
    minion_ip = "${cidrhost(var.master_subnet, var.master_ip + count.index+100)}"
  }
}


resource "openstack_blockstorage_volume_v2" "minion-blk" {
  count = "${var.minion_count}",
  size = "${var.minion_block_size}"
  name = "${var.vm_name_prefix}-${var.minion_block_name}${count.index}"
}

resource "openstack_compute_instance_v2" "salt-master" {
  count = "1"
  name = "${var.vm_name_prefix}-salt-master"
  key_pair = "${var.key_pair}"
  image_name = "${var.image_name}"
  flavor_name = "${var.master_flavor}"
  network  {
    name = "Ext-Net"
    access_network = true
  }
  network {
    name = "VLAN"
    fixed_ip_v4 = "${cidrhost(var.master_subnet, var.master_ip)}"
  }
  user_data = "${data.template_file.master-bootstrap.rendered}"
}

resource "openstack_compute_instance_v2" "salt-minion" {
  count = "${var.minion_count}"
  name = "${var.vm_name_prefix}-salt-minion-${count.index}"
  key_pair = "${var.key_pair}"
  image_name = "${var.image_name}"
  flavor_name = "${var.master_flavor}"
  network  {
    name = "Ext-Net"
    access_network = true
  }
  network {
    name = "VLAN"
    fixed_ip_v4 = "${cidrhost(var.master_subnet, var.master_ip + count.index+100)}"
  }
  volume {
    volume_id = "${element(openstack_blockstorage_volume_v2.minion-blk.*.id, count.index)}"
  }

  user_data = "${element(data.template_file.minion-bootstrap.*.rendered,count.index)}"

}

output "master-ip" {
  value = "${openstack_compute_instance_v2.salt-master.0.access_ip_v4}"
}

output "minion_ips" {
  value = "${join(" ", openstack_compute_instance_v2.salt-minion.*.access_ip_v4)}"
}
